import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

// Create Supabase client with service role key for database access
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '', 
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY')!;
const stripeWebhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

const stripe = new Stripe(stripeSecret, {
  appInfo: {
    name: 'Public Webhook Handler',
    version: '1.0.0',
  },
});

// This function is publicly accessible - no auth required
Deno.serve(async (req) => {
  try {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response(null, { 
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, stripe-signature',
        }
      });
    }

    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Get and verify Stripe signature
    const signature = req.headers.get('stripe-signature');
    if (!signature) {
      console.error('No Stripe signature found');
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

    console.log('✅ Webhook verified, processing event:', event.type);
    
    // Process the event asynchronously
    EdgeRuntime.waitUntil(handleEvent(event));

    // Return success immediately to Stripe
    return Response.json({ received: true });
    
  } catch (error: any) {
    console.error('Error processing webhook:', error);
    return Response.json({ error: error.message }, { status: 500 });
  }
});

async function handleEvent(event: Stripe.Event) {
  try {
    console.log(`🔄 Processing Stripe event: ${event.type}`);
    
    if (event.type === 'checkout.session.completed') {
      await handleCheckoutCompleted(event);
    } else if (event.type.startsWith('customer.subscription.')) {
      await handleSubscriptionEvent(event);
    } else {
      console.log(`ℹ️ Unhandled event type: ${event.type}`);
    }
  } catch (error) {
    console.error('Error in handleEvent:', error);
  }
}

async function handleCheckoutCompleted(event: Stripe.Event) {
  const session = event.data.object as Stripe.Checkout.Session;
  const customerId = session.customer as string;
  
  if (!customerId) {
    console.error('No customer ID in checkout session');
    return;
  }

  console.log(`💳 Processing checkout for customer: ${customerId}`);

  try {
    // Get line items to determine price ID
    const lineItems = await stripe.checkout.sessions.listLineItems(session.id);
    const priceId = lineItems.data[0]?.price?.id;

    // NEW PRICING: $99 = lifetime, $27.99 = yearly, $3.99 = monthly
    let purchase_type: 'lifetime' | 'monthly' | 'yearly' = 'monthly';
    
    if (session.amount_total && session.amount_total >= 9900) {
      purchase_type = 'lifetime'; // $99.00
    } else if (priceId === 'price_1RbnIfInTpoMSXouPdJBHz97' || (session.amount_total && session.amount_total === 2799)) {
      purchase_type = 'yearly'; // $27.99
    }

    console.log(`📊 Detected: ${purchase_type} subscription, Amount: $${(session.amount_total || 0) / 100}`);

    // Get subscription data for subscription purchases
    let subscriptionData: any = {
      subscription_id: null,
      price_id: priceId,
      current_period_start: null,
      current_period_end: null,
      cancel_at_period_end: false,
      subscription_status: null
    };

    if ((purchase_type === 'monthly' || purchase_type === 'yearly') && session.subscription) {
      try {
        const subscription = await stripe.subscriptions.retrieve(session.subscription as string);
        subscriptionData = {
          subscription_id: subscription.id,
          price_id: subscription.items.data[0]?.price?.id || priceId,
          current_period_start: subscription.current_period_start,
          current_period_end: subscription.current_period_end,
          cancel_at_period_end: subscription.cancel_at_period_end,
          subscription_status: subscription.status
        };
      } catch (error) {
        console.error('Error fetching subscription:', error);
      }
    }

    // Set default price IDs based on purchase type
    if (!subscriptionData.price_id) {
      if (purchase_type === 'lifetime') {
        subscriptionData.price_id = 'price_1RW02UInTpoMSXouhnQLA7Jn';
      } else if (purchase_type === 'yearly') {
        subscriptionData.price_id = 'price_1RbnIfInTpoMSXouPdJBHz97';
      } else {
        subscriptionData.price_id = 'price_1RW01zInTpoMSXoua1wZb9zY';
      }
    }

    // Get payment method details
    let payment_method_brand = 'card';
    let payment_method_last4 = '****';

    if (session.payment_intent) {
      try {
        const paymentIntent = await stripe.paymentIntents.retrieve(
          session.payment_intent as string,
          { expand: ['payment_method'] }
        );
        
        const paymentMethod = paymentIntent.payment_method as Stripe.PaymentMethod;
        if (paymentMethod?.card) {
          payment_method_brand = paymentMethod.card.brand || 'card';
          payment_method_last4 = paymentMethod.card.last4 || '****';
        }
      } catch (error) {
        console.error('Error fetching payment method:', error);
      }
    }

    // Create order record
    const orderData = {
      checkout_session_id: session.id,
      payment_intent_id: session.payment_intent || `pi_generated_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      customer_id: customerId,
      amount_subtotal: session.amount_subtotal || session.amount_total,
      amount_total: session.amount_total,
      currency: session.currency,
      payment_status: session.payment_status,
      status: 'completed',
      email: session.customer_details?.email,
      purchase_type,
      payment_method_brand,
      payment_method_last4,
      ...subscriptionData
    };

    console.log(`💾 Creating order:`, { 
      customer_id: customerId, 
      purchase_type, 
      amount: session.amount_total,
      email: session.customer_details?.email 
    });

    // Insert order into database
    const { error: orderError } = await supabase
      .from('stripe_orders')
      .insert(orderData);

    if (orderError) {
      console.error('❌ Failed to insert order:', orderError);
      throw orderError;
    }

    console.log(`✅ Successfully created order for session: ${session.id}`);

    // Create/update customer record
    if (session.customer_details?.email) {
      const customerData = {
        customer_id: customerId,
        email: session.customer_details.email,
        payment_type: purchase_type,
        beta_user: true
      };

      const { error: customerError } = await supabase
        .from('stripe_customers')
        .upsert(customerData, { 
          onConflict: 'customer_id',
          ignoreDuplicates: false 
        });

      if (customerError) {
        console.error('⚠️ Failed to upsert customer:', customerError);
        // Don't throw - order creation is more important
      } else {
        console.log(`✅ Updated customer record for: ${session.customer_details.email}`);
      }
    }

  } catch (error) {
    console.error('❌ Error processing checkout session:', error);
    throw error;
  }
}

async function handleSubscriptionEvent(event: Stripe.Event) {
  const subscription = event.data.object as Stripe.Subscription;
  const customerId = subscription.customer as string;
  
  console.log(`🔄 Processing subscription event: ${event.type} for customer: ${customerId}`);
  
  try {
    // Update subscription status in orders table
    const updateData = {
      subscription_status: subscription.status,
      cancel_at_period_end: subscription.cancel_at_period_end,
      current_period_end: subscription.current_period_end,
      updated_at: new Date().toISOString()
    };

    const { error } = await supabase
      .from('stripe_orders')
      .update(updateData)
      .eq('customer_id', customerId)
      .eq('status', 'completed');

    if (error) {
      console.error('❌ Failed to update subscription status:', error);
    } else {
      console.log(`✅ Updated subscription status to: ${subscription.status}`);
    }
    
  } catch (error) {
    console.error('❌ Error handling subscription event:', error);
  }
} 