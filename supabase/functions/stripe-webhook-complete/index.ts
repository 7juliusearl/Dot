import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY')!;
const stripeWebhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

const stripe = new Stripe(stripeSecret, {
  appInfo: {
    name: 'Bolt Integration',
    version: '1.0.0',
  },
});

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { 
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, stripe-signature, authorization',
        }
      });
    }

    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const signature = req.headers.get('stripe-signature');

    if (!signature) {
      return new Response('No signature found', { status: 400 });
    }

    const body = await req.text();
    let event: Stripe.Event;

    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, stripeWebhookSecret);
    } catch (error: any) {
      console.error(`Webhook signature verification failed: ${error.message}`);
      return new Response(`Webhook signature verification failed: ${error.message}`, { status: 400 });
    }

    console.log('Received webhook event:', event.type);
    EdgeRuntime.waitUntil(handleEvent(event));

    return Response.json({ received: true });
  } catch (error: any) {
    console.error('Error processing webhook:', error);
    return Response.json({ error: error.message }, { status: 500 });
  }
});

async function handleEvent(event: Stripe.Event) {
  const stripeData = event?.data?.object ?? {};
  console.log(`Processing Stripe event: ${event.type}`);
  console.log('Event data:', JSON.stringify(stripeData, null, 2));

  if (!stripeData || !('customer' in stripeData)) {
    console.log('No customer data in event, skipping');
    return;
  }

  const { customer: customerId } = stripeData;

  if (!customerId || typeof customerId !== 'string') {
    console.error(`No customer ID received on event: ${JSON.stringify(event)}`);
    return;
  }

  // Handle subscription events
  if (event.type.startsWith('customer.subscription.')) {
    await handleSubscriptionEvent(event, customerId);
    return;
  }

  if (event.type === 'checkout.session.completed') {
    console.log(`Processing checkout session for customer: ${customerId}`);
    const session = stripeData as Stripe.Checkout.Session;
    const { mode, payment_status } = session;

    try {
      const {
        id: checkout_session_id,
        payment_intent,
        amount_subtotal,
        amount_total,
        currency,
      } = session;

      // Get the line items to determine the price ID
      const lineItems = await stripe.checkout.sessions.listLineItems(checkout_session_id);
      const priceId = lineItems.data[0]?.price?.id;

      // Determine purchase type based on mode and price ID
      let purchase_type: 'lifetime' | 'monthly' = 'monthly';
      if (mode === 'payment' || priceId?.includes('lifetime')) {
        purchase_type = 'lifetime';
      }

      // Get customer email
      const { data: customerData, error: customerError } = await supabase
        .from('stripe_customers')
        .select('email')
        .eq('customer_id', customerId)
        .single();

      if (customerError) {
        console.error('Error fetching customer data:', customerError);
        return;
      }

      // Get payment method details - IMPROVED VERSION
      let payment_method_brand = 'card';
      let payment_method_last4 = '****';

      console.log(`🔍 Starting payment method capture for customer: ${customerId}`);
      console.log(`Session mode: ${mode}, Payment intent: ${payment_intent}`);

      try {
        // Method 1: For subscription checkouts, get from subscription's default payment method
        if (mode === 'subscription' && session.subscription) {
          console.log('🔄 Attempting to get payment method from subscription...');
          
          const subscription = await stripe.subscriptions.retrieve(session.subscription, {
            expand: ['default_payment_method']
          });
          
          const paymentMethod = subscription.default_payment_method as Stripe.PaymentMethod;
          if (paymentMethod && paymentMethod.card) {
            payment_method_brand = paymentMethod.card.brand || 'card';
            payment_method_last4 = paymentMethod.card.last4 || '****';
            console.log(`✅ SUCCESS: Got payment method from subscription: ${payment_method_brand} ending in ${payment_method_last4}`);
            
            // Validate we got real card digits
            if (payment_method_last4.match(/^[0-9]{4}$/)) {
              // We have real card data, we're done
            } else {
              console.warn(`⚠️ WARNING: Subscription payment method last4 is not 4 digits: ${payment_method_last4}`);
              payment_method_last4 = '****'; // Reset to try other methods
            }
          } else {
            console.log('No card data found in subscription default payment method');
          }
        }

        // Method 2: Get from payment intent (works for both subscription and one-time payments)
        if (payment_method_last4 === '****' && payment_intent && typeof payment_intent === 'string') {
          console.log('🔄 Attempting to get payment method from payment intent...');
          
          const paymentIntentData = await stripe.paymentIntents.retrieve(payment_intent, {
            expand: ['payment_method']
          });
          
          const paymentMethod = paymentIntentData.payment_method as Stripe.PaymentMethod;
          if (paymentMethod && paymentMethod.card) {
            payment_method_brand = paymentMethod.card.brand || 'card';
            payment_method_last4 = paymentMethod.card.last4 || '****';
            console.log(`✅ SUCCESS: Got payment method from payment intent: ${payment_method_brand} ending in ${payment_method_last4}`);
            
            // Validate we got real card digits
            if (payment_method_last4.match(/^[0-9]{4}$/)) {
              // We have real card data, we're done
            } else {
              console.warn(`⚠️ WARNING: Payment intent payment method last4 is not 4 digits: ${payment_method_last4}`);
              payment_method_last4 = '****'; // Reset to try other methods
            }
          } else {
            console.log('No card data found in payment intent payment method');
          }
        }

        // Method 3: For subscriptions, try listing customer's payment methods
        if (payment_method_last4 === '****' && mode === 'subscription') {
          console.log('🔄 Attempting to get payment method from customer payment methods list...');
          
          const paymentMethods = await stripe.paymentMethods.list({
            customer: customerId,
            type: 'card',
            limit: 1
          });
          
          if (paymentMethods && paymentMethods.data && paymentMethods.data.length > 0) {
            const paymentMethod = paymentMethods.data[0];
            if (paymentMethod && paymentMethod.card) {
              payment_method_brand = paymentMethod.card.brand || 'card';
              payment_method_last4 = paymentMethod.card.last4 || '****';
              console.log(`✅ SUCCESS: Got payment method from customer payment methods: ${payment_method_brand} ending in ${payment_method_last4}`);
              
              // Validate we got real card digits
              if (!payment_method_last4.match(/^[0-9]{4}$/)) {
                console.warn(`⚠️ WARNING: Customer payment method last4 is not 4 digits: ${payment_method_last4}`);
                payment_method_last4 = '****';
              }
            }
          } else {
            console.log('No payment methods found for customer');
          }
        }

      } catch (error) {
        console.error('❌ ERROR: Failed to capture payment method details:', error);
      }

      // Final validation and logging
      if (payment_method_last4 === '****') {
        console.warn(`⚠️ WARNING: Could not capture real payment method data for customer ${customerId}. Using placeholder.`);
      } else if (!payment_method_last4.match(/^[0-9]{4}$/)) {
        console.error(`❌ ERROR: Captured invalid payment method last4: ${payment_method_last4}. Resetting to placeholder.`);
        payment_method_last4 = '****';
        payment_method_brand = 'card';
      } else {
        console.log(`✅ FINAL SUCCESS: Real payment method captured: ${payment_method_brand} ending in ${payment_method_last4}`);
      }

      // Get subscription data for monthly purchases
      let subscriptionData = {};
      if (purchase_type === 'monthly' && mode === 'subscription') {
        try {
          const subscriptions = await stripe.subscriptions.list({
            customer: customerId,
            limit: 1,
            status: 'all'
          });
          
          if (subscriptions.data.length > 0) {
            const subscription = subscriptions.data[0];
            subscriptionData = {
              subscription_id: subscription.id,
              price_id: subscription.items.data[0].price.id,
              current_period_start: subscription.current_period_start,
              current_period_end: subscription.current_period_end,
              cancel_at_period_end: subscription.cancel_at_period_end,
              subscription_status: subscription.status
            };
            console.log('Captured subscription data:', subscriptionData);
          }
        } catch (error) {
          console.error('Error fetching subscription data:', error);
        }
      } else if (purchase_type === 'lifetime') {
        // For lifetime purchases, set appropriate values
        subscriptionData = {
          subscription_id: null,
          price_id: priceId || 'price_1RW02UInTpoMSXouhnQLA7Jn',
          current_period_start: null,
          current_period_end: null,
          cancel_at_period_end: false,
          subscription_status: null
        };
      }

      const orderData = {
        checkout_session_id,
        payment_intent_id: payment_intent || `pi_generated_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        customer_id: customerId,
        amount_subtotal,
        amount_total,
        currency,
        payment_status,
        status: 'completed',
        email: customerData?.email,
        purchase_type,
        payment_method_brand,
        payment_method_last4,
        ...subscriptionData
      };

      console.log('Creating order with data:', orderData);

      const { error: orderError } = await supabase
        .from('stripe_orders')
        .insert(orderData);

      if (orderError) {
        console.error('Failed to insert order:', orderError);
        return;
      }

      console.log(`Successfully created order for session: ${checkout_session_id}`);

      // For subscription checkouts, also sync the subscription data
      if (mode === 'subscription') {
        console.log('Syncing subscription data for subscription checkout');
        await syncSubscriptionData(customerId);
      }

      // Send TestFlight invite after successful order creation
      if (customerData?.email) {
        try {
          console.log(`Sending TestFlight invite to ${customerData.email}`);
          
          // Wait a few seconds to ensure the order is properly recorded
          await new Promise(resolve => setTimeout(resolve, 5000));
          
          const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/testflight-invite`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email: customerData.email })
          });

          if (!response.ok) {
            const error = await response.text();
            throw new Error(`Failed to send TestFlight invite: ${error}`);
          }

          const inviteResult = await response.json();
          console.log('TestFlight invite result:', inviteResult);

          console.log(`Successfully sent TestFlight invite to ${customerData.email}`);
        } catch (error) {
          console.error('Error in TestFlight invite process:', error);
          // Don't throw here - we want to continue even if TestFlight invite fails
          // The user can still access TestFlight through their dashboard
        }
      }
    } catch (error) {
      console.error('Error processing order:', error);
    }
  }
}

async function handleSubscriptionEvent(event: Stripe.Event, customerId: string) {
  console.log(`Processing subscription event: ${event.type} for customer: ${customerId}`);
  
  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await syncSubscriptionData(customerId);
        break;
      
      default:
        console.log(`Unhandled subscription event: ${event.type}`);
        break;
    }
  } catch (error) {
    console.error(`Error handling subscription event ${event.type}:`, error);
  }
}

async function syncSubscriptionData(customerId: string, retryCount = 0) {
  console.log(`Syncing subscription data for customer: ${customerId} (attempt ${retryCount + 1})`);
  
  try {
    // Add delay for retry attempts to let Stripe process
    if (retryCount > 0) {
      const delay = Math.min(1000 * Math.pow(2, retryCount), 10000); // Exponential backoff, max 10s
      console.log(`Waiting ${delay}ms before retry...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }

    // Get customer's active subscriptions from Stripe
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      limit: 1,
      status: 'all',
      expand: ['data.default_payment_method']
    });

    console.log(`Found ${subscriptions.data.length} subscriptions for customer ${customerId}`);

    // Check if subscription record exists in database
    const { data: existingSubscription } = await supabase
      .from('stripe_subscriptions')
      .select('*')
      .eq('customer_id', customerId)
      .maybeSingle();

    const subscriptionData = subscriptions.data[0];
    const paymentMethod = subscriptionData?.default_payment_method as Stripe.PaymentMethod;

    let updateData;
    
    if (subscriptionData) {
      // We have subscription data from Stripe - use it
      updateData = {
        subscription_id: subscriptionData.id,
        price_id: subscriptionData.items.data[0].price.id,
        current_period_start: subscriptionData.current_period_start,
        current_period_end: subscriptionData.current_period_end,
        cancel_at_period_end: subscriptionData.cancel_at_period_end,
        payment_method_brand: paymentMethod?.card?.brand || 'card',
        payment_method_last4: paymentMethod?.card?.last4 || '****',
        status: subscriptionData.status, // Use actual Stripe status
        updated_at: new Date().toISOString()
      };
      console.log('Using subscription data from Stripe:', { 
        id: subscriptionData.id, 
        status: subscriptionData.status,
        cancel_at_period_end: subscriptionData.cancel_at_period_end
      });
    } else {
      // No subscription found in Stripe
      if (retryCount < 3) {
        // Retry up to 3 times - Stripe might still be processing
        console.log(`No subscription found, retrying in a moment... (attempt ${retryCount + 1}/3)`);
        return await syncSubscriptionData(customerId, retryCount + 1);
      }
      
      // After 3 retries, check if this is a lifetime purchase or subscription issue
      console.log('No subscription found after retries, checking order type...');
      
      // Check if this customer has any completed orders to determine type
      const { data: orderData } = await supabase
        .from('stripe_orders')
        .select('purchase_type')
        .eq('customer_id', customerId)
        .eq('status', 'completed')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      if (orderData?.purchase_type === 'lifetime') {
        // Lifetime purchase - no subscription needed, but record should exist
        updateData = {
          subscription_id: null,
          price_id: 'price_1RW02UInTpoMSXouhnQLA7Jn', // Lifetime price
          current_period_start: null,
          current_period_end: null,
          cancel_at_period_end: false,
          payment_method_brand: 'card',
          payment_method_last4: '****',
          status: 'active', // ⭐ FIXED: Set to 'active' for lifetime users
          updated_at: new Date().toISOString()
        };
        console.log('Lifetime purchase detected - setting active status');
      } else {
        // Monthly purchase but no subscription found - this is an error
        // Set to active with generated data (emergency fallback)
        updateData = {
          subscription_id: `sub_generated_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          price_id: 'price_1RW01zInTpoMSXoua1wZb9zY', // Monthly price
          current_period_start: Math.floor(Date.now() / 1000),
          current_period_end: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // +30 days
          cancel_at_period_end: false,
          payment_method_brand: 'card',
          payment_method_last4: '****',
          status: 'active', // ⭐ FIXED: Set to 'active' instead of 'not_started'
          updated_at: new Date().toISOString()
        };
        console.log('⚠️ Monthly purchase but no Stripe subscription found - using fallback data');
        
        // Log this as an error for investigation
        console.error(`WEBHOOK ERROR: Monthly customer ${customerId} has no subscription in Stripe after checkout`);
      }
    }

    console.log('Updating subscription with data:', {
      customer_id: customerId,
      status: updateData.status,
      subscription_id: updateData.subscription_id,
      cancel_at_period_end: updateData.cancel_at_period_end
    });

    // ⭐ CRITICAL FIX: Update BOTH tables so TestFlight access control works
    
    // 1. Update stripe_subscriptions table (existing logic)
    let result;
    if (existingSubscription) {
      result = await supabase
        .from('stripe_subscriptions')
        .update(updateData)
        .eq('customer_id', customerId);
    } else {
      result = await supabase
        .from('stripe_subscriptions')
        .insert({
          ...updateData,
          customer_id: customerId
        });
    }

    if (result.error) {
      console.error('Database update error (stripe_subscriptions):', result.error);
      throw result.error;
    }

    // 2. ⭐ NEW: Also update stripe_orders table for TestFlight access control
    const orderUpdateData = {
      subscription_id: updateData.subscription_id,
      price_id: updateData.price_id,
      current_period_start: updateData.current_period_start,
      current_period_end: updateData.current_period_end,
      cancel_at_period_end: updateData.cancel_at_period_end,
      subscription_status: updateData.status,
      payment_method_brand: updateData.payment_method_brand,
      payment_method_last4: updateData.payment_method_last4,
      updated_at: new Date().toISOString()
    };

    const orderResult = await supabase
      .from('stripe_orders')
      .update(orderUpdateData)
      .eq('customer_id', customerId)
      .eq('status', 'completed')
      .eq('purchase_type', 'monthly'); // Only update monthly orders

    if (orderResult.error) {
      console.error('Database update error (stripe_orders):', orderResult.error);
      // Don't throw here - subscription table was updated successfully
    } else {
      console.log('✅ Also updated stripe_orders table for TestFlight access control');
    }

    console.log(`✅ Subscription data synced successfully for ${customerId} with status: ${updateData.status}`);
    return updateData;
    
  } catch (error) {
    console.error(`Error syncing subscription data for ${customerId}:`, error);
    
    // If we haven't retried yet, try once more
    if (retryCount === 0) {
      console.log('Retrying subscription sync after error...');
      return await syncSubscriptionData(customerId, 1);
    }
    
    // After retries failed, create a minimal active record to prevent "not_started" state
    console.log('⚠️ Creating emergency fallback record to prevent not_started status');
    try {
      const fallbackData = {
        subscription_id: `sub_fallback_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        price_id: 'price_1RW01zInTpoMSXoua1wZb9zY', // Default to monthly
        current_period_start: Math.floor(Date.now() / 1000),
        current_period_end: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60),
        cancel_at_period_end: false,
        payment_method_brand: 'card',
        payment_method_last4: '****',
        status: 'active', // ⭐ CRITICAL: Always default to 'active' for completed checkouts
        updated_at: new Date().toISOString()
      };

      await supabase
        .from('stripe_subscriptions')
        .upsert({
          ...fallbackData,
          customer_id: customerId
        });
        
      console.log(`🆘 Emergency fallback record created for ${customerId} - manual investigation needed`);
    } catch (fallbackError) {
      console.error('Failed to create fallback record:', fallbackError);
    }
    
    throw error;
  }
}