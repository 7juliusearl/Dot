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
      return new Response(null, { status: 204 });
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

      const orderData = {
        checkout_session_id,
        payment_intent_id: payment_intent,
        customer_id: customerId,
        amount_subtotal,
        amount_total,
        currency,
        payment_status,
        status: 'completed',
        email: customerData?.email,
        purchase_type
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

async function syncSubscriptionData(customerId: string) {
  console.log(`Syncing subscription data for customer: ${customerId}`);
  
  try {
    // Get customer's active subscriptions from Stripe
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      limit: 1,
      status: 'all',
      expand: ['data.default_payment_method']
    });

    console.log('Found subscriptions:', subscriptions.data.length);

    // Check if subscription record exists
    const { data: existingSubscription } = await supabase
      .from('stripe_subscriptions')
      .select('*')
      .eq('customer_id', customerId)
      .maybeSingle();

    const subscriptionData = subscriptions.data[0];
    const paymentMethod = subscriptionData?.default_payment_method as Stripe.PaymentMethod;

    const updateData = subscriptionData ? {
      subscription_id: subscriptionData.id,
      price_id: subscriptionData.items.data[0].price.id,
      current_period_start: subscriptionData.current_period_start,
      current_period_end: subscriptionData.current_period_end,
      cancel_at_period_end: subscriptionData.cancel_at_period_end,
      payment_method_brand: paymentMethod?.card?.brand || null,
      payment_method_last4: paymentMethod?.card?.last4 || null,
      status: subscriptionData.status,
      updated_at: new Date().toISOString()
    } : {
      subscription_id: null,
      price_id: null,
      current_period_start: null,
      current_period_end: null,
      cancel_at_period_end: false,
      payment_method_brand: null,
      payment_method_last4: null,
      status: 'not_started',
      updated_at: new Date().toISOString()
    };

    console.log('Updating subscription with data:', updateData);

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
          customer_id
        });
    }

    if (result.error) {
      console.error('Database update error:', result.error);
      throw result.error;
    }

    console.log('Subscription data synced successfully');
  } catch (error) {
    console.error('Error syncing subscription data:', error);
    throw error;
  }
}