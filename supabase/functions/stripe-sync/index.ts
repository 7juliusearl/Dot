import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.39.7';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16'
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    const { customer_id } = await req.json();
    console.log('Processing sync request for customer:', customer_id);

    let actualCustomerId = customer_id;

    // If customer_id is 'auto', get it from the authenticated user
    if (customer_id === 'auto') {
      const authHeader = req.headers.get('Authorization');
      if (!authHeader) {
        return new Response(
          JSON.stringify({ error: 'Authorization header required' }),
          { 
            status: 401, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        );
      }

      const token = authHeader.replace('Bearer ', '');
      
      // Get the user from the token
      const { data: { user }, error: userError } = await supabase.auth.getUser(token);
      
      if (userError || !user) {
        return new Response(
          JSON.stringify({ error: 'Invalid authentication token' }),
          { 
            status: 401, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        );
      }
      
      // Get the user's customer_id from the database
      const { data: customerData, error: customerError } = await supabase
        .from('stripe_customers')
        .select('customer_id')
        .eq('user_id', user.id)
        .single();

      if (customerError || !customerData) {
        return new Response(
          JSON.stringify({ error: 'Customer not found for authenticated user' }),
          { 
            status: 404, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        );
      }

      actualCustomerId = customerData.customer_id;
    }

    if (!actualCustomerId) {
      return new Response(
        JSON.stringify({ error: 'Customer ID is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Get customer's subscriptions from Stripe
    console.log('Fetching subscriptions from Stripe...');
    const subscriptions = await stripe.subscriptions.list({
      customer: actualCustomerId,
      limit: 1,
      status: 'all',
      expand: ['data.default_payment_method']
    });

    console.log('Found subscriptions:', subscriptions.data.length);

    // Check if subscription record exists
    const { data: existingSubscription } = await supabase
      .from('stripe_subscriptions')
      .select('*')
      .eq('customer_id', actualCustomerId)
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
        .eq('customer_id', actualCustomerId);
    } else {
      result = await supabase
        .from('stripe_subscriptions')
        .insert({
          ...updateData,
          customer_id: actualCustomerId
        });
    }

    if (result.error) {
      console.error('Database update error:', result.error);
      throw result.error;
    }

    console.log('Subscription updated successfully');

    return new Response(
      JSON.stringify({ 
        message: 'Subscription updated successfully',
        data: updateData
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error syncing subscription:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});