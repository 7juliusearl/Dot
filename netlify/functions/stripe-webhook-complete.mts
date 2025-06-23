import type { Context, Config } from "@netlify/functions";
import { createHmac } from 'crypto';

export default async (req: Request, context: Context) => {
  console.log('Complete webhook handler invoked:', req.method);

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Get environment variables
    const supabaseUrl = process.env.VITE_SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables');
      return new Response('Configuration error', { status: 500 });
    }

    // Get the raw request body for signature verification
    const body = await req.text();
    const stripeSignature = req.headers.get('stripe-signature');

    console.log('Webhook received:', {
      hasSignature: !!stripeSignature,
      bodyLength: body.length
    });

    // Verify Stripe signature if webhook secret is available
    if (stripeWebhookSecret && stripeSignature) {
      try {
        const signature = stripeSignature.split(',').reduce((acc, part) => {
          const [key, value] = part.split('=');
          acc[key] = value;
          return acc;
        }, {} as Record<string, string>);

        const expectedSignature = createHmac('sha256', stripeWebhookSecret)
          .update(signature.t + '.' + body)
          .digest('hex');

        if (signature.v1 !== expectedSignature) {
          console.error('Invalid Stripe signature');
          return new Response('Invalid signature', { status: 400 });
        }
      } catch (error) {
        console.error('Signature verification error:', error);
        return new Response('Signature verification failed', { status: 400 });
      }
    }

    // Parse the webhook event
    let event;
    try {
      event = JSON.parse(body);
    } catch (e) {
      console.error('Failed to parse JSON:', e);
      return new Response('Invalid JSON', { status: 400 });
    }

    console.log('Processing event:', event.type, event.id);

    // Handle checkout.session.completed events
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      
      console.log('Checkout session completed:', {
        sessionId: session.id,
        customerId: session.customer,
        paymentIntent: session.payment_intent,
        email: session.customer_details?.email,
        amountTotal: session.amount_total,
        mode: session.mode
      });

      // Insert order record directly into Supabase
      try {
        // Determine purchase type based on mode, amount, and price ID
        let purchaseType = 'monthly';
        
        // Get line items to check price ID
        const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
        let detectedPriceId = null;
        
        if (stripeSecretKey && session.subscription) {
          try {
            const subscriptionResponse = await fetch(`https://api.stripe.com/v1/subscriptions/${session.subscription}`, {
              headers: {
                'Authorization': `Bearer ${stripeSecretKey}`,
                'Content-Type': 'application/x-www-form-urlencoded'
              }
            });
            
            if (subscriptionResponse.ok) {
              const subscription = await subscriptionResponse.json();
              detectedPriceId = subscription.items.data[0]?.price?.id;
            }
          } catch (error) {
            console.error('Error fetching subscription for price detection:', error);
          }
        }

        // Determine purchase type based on mode, amount, and price ID
        if (session.mode === 'payment' || session.amount_total > 1000) {
          purchaseType = 'lifetime';
        } else if (detectedPriceId === 'price_1RbnIfInTpoMSXouPdJBHz97' || session.amount_total >= 2700) {
          // Yearly subscription: specific price ID or amount >= $27
          purchaseType = 'yearly';
        }

        console.log('Detected purchase type:', purchaseType, 'Price ID:', detectedPriceId, 'Amount:', session.amount_total);

        // For subscriptions (monthly/yearly), get the subscription_id from Stripe
        let subscriptionData: any = {
          subscription_id: null,
          price_id: null,
          current_period_start: null,
          current_period_end: null,
          cancel_at_period_end: false,
          subscription_status: null
        };

        if ((purchaseType === 'monthly' || purchaseType === 'yearly') && session.mode === 'subscription' && session.subscription) {
          // Fetch subscription details from Stripe
          try {
            const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
            if (stripeSecretKey) {
              const subscriptionResponse = await fetch(`https://api.stripe.com/v1/subscriptions/${session.subscription}`, {
                headers: {
                  'Authorization': `Bearer ${stripeSecretKey}`,
                  'Content-Type': 'application/x-www-form-urlencoded'
                }
              });
              
              if (subscriptionResponse.ok) {
                const subscription = await subscriptionResponse.json();
                const defaultPriceId = purchaseType === 'yearly' 
                  ? 'price_1RbnIfInTpoMSXouPdJBHz97' 
                  : 'price_1RW01zInTpoMSXoua1wZb9zY';
                
                subscriptionData = {
                  subscription_id: subscription.id,
                  price_id: subscription.items.data[0]?.price?.id || defaultPriceId,
                  current_period_start: subscription.current_period_start,
                  current_period_end: subscription.current_period_end,
                  cancel_at_period_end: subscription.cancel_at_period_end,
                  subscription_status: subscription.status
                };
                console.log('Captured subscription data:', subscriptionData);
              } else {
                console.error('Failed to fetch subscription from Stripe:', subscriptionResponse.status);
              }
            }
          } catch (error) {
            console.error('Error fetching subscription from Stripe:', error);
          }
        } else if (purchaseType === 'lifetime') {
          // For lifetime purchases, set appropriate values
          subscriptionData.price_id = 'price_1RW02UInTpoMSXouhnQLA7Jn';
        }

        // Get payment method details (card brand and last 4 digits)
        let paymentMethodData = {
          payment_method_brand: 'card',
          payment_method_last4: '****'
        };

        try {
          const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
          if (stripeSecretKey && session.payment_intent) {
            const paymentIntentResponse = await fetch(`https://api.stripe.com/v1/payment_intents/${session.payment_intent}?expand[]=payment_method`, {
              headers: {
                'Authorization': `Bearer ${stripeSecretKey}`,
                'Content-Type': 'application/x-www-form-urlencoded'
              }
            });
            
            if (paymentIntentResponse.ok) {
              const paymentIntent = await paymentIntentResponse.json();
              const paymentMethod = paymentIntent.payment_method;
              
              if (paymentMethod?.card) {
                paymentMethodData = {
                  payment_method_brand: paymentMethod.card.brand || 'card',
                  payment_method_last4: paymentMethod.card.last4 || '****'
                };
                console.log('Captured payment method:', paymentMethodData);
              }
            } else {
              console.error('Failed to fetch payment intent from Stripe:', paymentIntentResponse.status);
            }
          }
        } catch (error) {
          console.error('Error fetching payment method details:', error);
          // Continue with defaults
        }
         
        const orderData = {
          checkout_session_id: session.id,
          payment_intent_id: session.payment_intent,
          customer_id: session.customer,
          amount_subtotal: session.amount_subtotal || session.amount_total,
          amount_total: session.amount_total,
          currency: session.currency,
          payment_status: session.payment_status,
          status: 'completed',
          purchase_type: purchaseType,
          email: session.customer_details?.email || session.customer_email,
          ...subscriptionData,
          ...paymentMethodData
        };

        console.log('Creating order with type:', purchaseType, 'for amount:', session.amount_total, 'subscription_id:', subscriptionData.subscription_id);

        // CRITICAL FIX: First, ensure customer record exists to link user_id to customer_id
        // This is essential for frontend verification to work
        const customerEmail = session.customer_details?.email || session.customer_email;
        if (customerEmail) {
          try {
            // Query auth.users directly to find user by email
            const authResponse = await fetch(`${supabaseUrl}/rest/v1/auth.users?email=eq.${encodeURIComponent(customerEmail)}&select=id,email`, {
              method: 'GET',
              headers: {
                'Authorization': `Bearer ${supabaseServiceKey}`,
                'apikey': supabaseServiceKey
              }
            });

            if (authResponse.ok) {
              const userData = await authResponse.json();
              if (userData && userData.length > 0) {
                const userId = userData[0].id;
                
                // Create/update customer record to link user_id to customer_id
                const customerData = {
                  user_id: userId,
                  customer_id: session.customer,
                  email: customerEmail,
                  payment_type: purchaseType,
                  beta_user: true
                };

                // Use UPSERT to handle duplicates
                const customerResponse = await fetch(`${supabaseUrl}/rest/v1/stripe_customers`, {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${supabaseServiceKey}`,
                    'apikey': supabaseServiceKey,
                    'Prefer': 'resolution=merge-duplicates'
                  },
                  body: JSON.stringify(customerData)
                });

                if (customerResponse.ok) {
                  console.log('Successfully created/updated customer record for user:', userId);
                } else {
                  const customerError = await customerResponse.text();
                  console.error('Failed to create customer record:', customerResponse.status, customerError);
                  // Continue anyway - order creation is still important
                }
              } else {
                console.log('User not found in auth.users for email:', customerEmail);
                // This is expected for some payments - continue with order creation
              }
            }
          } catch (error) {
            console.error('Error linking customer to user:', error);
            // Continue anyway - order creation is still important
          }
        }

        // Create the order record
        const supabaseResponse = await fetch(`${supabaseUrl}/rest/v1/stripe_orders`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey,
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify(orderData)
        });

        if (supabaseResponse.ok) {
          console.log('Successfully created order record');
          return new Response('Webhook processed successfully', { status: 200 });
        } else {
          const errorText = await supabaseResponse.text();
          console.error('Failed to create order:', supabaseResponse.status, errorText);
          return new Response('Database error', { status: 500 });
        }

      } catch (dbError) {
        console.error('Database operation failed:', dbError);
        return new Response('Database error', { status: 500 });
      }
    }

    // Handle subscription events
    if (event.type.startsWith('customer.subscription.')) {
      const subscription = event.data.object;
      
      console.log('Subscription event:', {
        type: event.type,
        subscriptionId: subscription.id,
        customerId: subscription.customer,
        status: subscription.status
      });

      try {
        // Get payment method details for subscription updates
        let subscriptionPaymentData: any = {};
        
        try {
          const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
          if (stripeSecretKey) {
            const subscriptionResponse = await fetch(`https://api.stripe.com/v1/subscriptions/${subscription.id}?expand[]=default_payment_method`, {
              headers: {
                'Authorization': `Bearer ${stripeSecretKey}`,
                'Content-Type': 'application/x-www-form-urlencoded'
              }
            });
            
            if (subscriptionResponse.ok) {
              const subscriptionDetail = await subscriptionResponse.json();
              const paymentMethod = subscriptionDetail.default_payment_method;
              
              if (paymentMethod?.card) {
                subscriptionPaymentData = {
                  payment_method_brand: paymentMethod.card.brand || 'card',
                  payment_method_last4: paymentMethod.card.last4 || '****'
                };
                console.log('Captured subscription payment method:', subscriptionPaymentData);
              }
            }
          }
        } catch (error) {
          console.error('Error fetching subscription payment method:', error);
        }

        // Update subscription data in existing monthly orders
        const updateData = {
          subscription_id: subscription.id,
          price_id: subscription.items.data[0]?.price?.id || 'price_1RW01zInTpoMSXoua1wZb9zY',
          current_period_start: subscription.current_period_start,
          current_period_end: subscription.current_period_end,
          cancel_at_period_end: subscription.cancel_at_period_end,
          subscription_status: subscription.status,
          ...subscriptionPaymentData
        };

        const supabaseResponse = await fetch(`${supabaseUrl}/rest/v1/stripe_orders?customer_id=eq.${subscription.customer}&purchase_type=eq.monthly`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey
          },
          body: JSON.stringify(updateData)
        });

        if (supabaseResponse.ok) {
          console.log('Successfully updated subscription data');
          return new Response('Subscription event processed', { status: 200 });
        } else {
          const errorText = await supabaseResponse.text();
          console.error('Failed to update subscription:', supabaseResponse.status, errorText);
          return new Response('Database error', { status: 500 });
        }

      } catch (dbError) {
        console.error('Subscription update failed:', dbError);
        return new Response('Database error', { status: 500 });
      }
    }

    // For other event types, just acknowledge
    console.log('Event acknowledged:', event.type);
    return new Response('Event acknowledged', { status: 200 });

  } catch (error) {
    console.error('Webhook processing error:', error);
    return new Response('Internal server error', { status: 500 });
  }
};

export const config: Config = {
  path: "/api/stripe-webhook-complete"
}; 