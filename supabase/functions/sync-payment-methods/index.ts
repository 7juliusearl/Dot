import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '', 
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  appInfo: { name: 'Payment Method Sync', version: '1.0.0' },
});

// Validate that last4 is actually 4 digits
function validateLast4(last4: string | null | undefined): boolean {
  if (!last4) return false;
  return /^[0-9]{4}$/.test(last4);
}

// Sync payment method data for a single customer
async function syncCustomerPaymentMethod(customerId: string): Promise<any> {
  console.log(`🔄 Syncing payment method for customer: ${customerId}`);
  
  try {
    // Method 1: Get from customer's payment methods
    const paymentMethods = await stripe.paymentMethods.list({
      customer: customerId,
      type: 'card',
      limit: 5
    });
    
    let paymentMethodData = {
      payment_method_brand: 'card',
      payment_method_last4: '****'
    };
    
    if (paymentMethods.data && paymentMethods.data.length > 0) {
      for (const pm of paymentMethods.data) {
        if (pm.card?.brand && pm.card?.last4) {
          const brand = pm.card.brand;
          const last4 = pm.card.last4;
          
          if (validateLast4(last4)) {
            paymentMethodData = {
              payment_method_brand: brand,
              payment_method_last4: last4
            };
            console.log(`✅ Found real card data: ${brand} ending in ${last4}`);
            break; // Use first valid payment method
          }
        }
      }
    }
    
    // Method 2: If no payment methods, try getting from subscriptions
    if (paymentMethodData.payment_method_last4 === '****') {
      console.log('🔄 Trying subscription payment methods...');
      
      const subscriptions = await stripe.subscriptions.list({
        customer: customerId,
        limit: 3,
        expand: ['data.default_payment_method']
      });
      
      for (const subscription of subscriptions.data) {
        const pm = subscription.default_payment_method as Stripe.PaymentMethod;
        if (pm?.card?.brand && pm?.card?.last4) {
          const brand = pm.card.brand;
          const last4 = pm.card.last4;
          
          if (validateLast4(last4)) {
            paymentMethodData = {
              payment_method_brand: brand,
              payment_method_last4: last4
            };
            console.log(`✅ Found real card data from subscription: ${brand} ending in ${last4}`);
            break;
          }
        }
      }
    }
    
    // Method 3: If still no data, try recent payment intents
    if (paymentMethodData.payment_method_last4 === '****') {
      console.log('🔄 Trying recent payment intents...');
      
      const paymentIntents = await stripe.paymentIntents.list({
        customer: customerId,
        limit: 5,
        expand: ['data.payment_method']
      });
      
      for (const pi of paymentIntents.data) {
        const pm = pi.payment_method as Stripe.PaymentMethod;
        if (pm?.card?.brand && pm?.card?.last4) {
          const brand = pm.card.brand;
          const last4 = pm.card.last4;
          
          if (validateLast4(last4)) {
            paymentMethodData = {
              payment_method_brand: brand,
              payment_method_last4: last4
            };
            console.log(`✅ Found real card data from payment intent: ${brand} ending in ${last4}`);
            break;
          }
        }
      }
    }
    
    // Update database with real or clean placeholder data
    const { error: orderError } = await supabase
      .from('stripe_orders')
      .update({
        payment_method_brand: paymentMethodData.payment_method_brand,
        payment_method_last4: paymentMethodData.payment_method_last4,
        updated_at: new Date().toISOString()
      })
      .eq('customer_id', customerId)
      .eq('status', 'completed');

    if (orderError) {
      console.error(`❌ Failed to update orders for ${customerId}:`, orderError);
      throw orderError;
    }

    // Also update subscriptions if they exist
    const { error: subError } = await supabase
      .from('stripe_subscriptions')
      .update({
        payment_method_brand: paymentMethodData.payment_method_brand,
        payment_method_last4: paymentMethodData.payment_method_last4,
        updated_at: new Date().toISOString()
      })
      .eq('customer_id', customerId);

    // Don't throw on subscription errors since not all customers have subscriptions
    if (subError) {
      console.log(`ℹ️ Note: Could not update subscription for ${customerId} (may not exist)`);
    }

    // Log the sync result
    await supabase
      .from('sync_logs')
      .insert({
        customer_id: customerId,
        operation: 'payment_method_sync_from_stripe',
        status: paymentMethodData.payment_method_last4 === '****' ? 'no_data_found' : 'success',
        details: {
          payment_method_brand: paymentMethodData.payment_method_brand,
          payment_method_last4: paymentMethodData.payment_method_last4,
          timestamp: new Date().toISOString(),
          methods_tried: ['customer_payment_methods', 'subscription_payment_methods', 'payment_intents']
        }
      });

    return {
      customer_id: customerId,
      success: true,
      payment_method_brand: paymentMethodData.payment_method_brand,
      payment_method_last4: paymentMethodData.payment_method_last4,
      has_real_data: paymentMethodData.payment_method_last4 !== '****'
    };

  } catch (error) {
    console.error(`❌ Error syncing customer ${customerId}:`, error);
    
    // Log the error
    await supabase
      .from('sync_logs')
      .insert({
        customer_id: customerId,
        operation: 'payment_method_sync_from_stripe',
        status: 'error',
        details: {
          error: error.message,
          timestamp: new Date().toISOString()
        }
      });

    return {
      customer_id: customerId,
      success: false,
      error: error.message
    };
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { 
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        }
      });
    }

    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const body = await req.json();
    const { customer_id, sync_all = false, limit = 10 } = body;

    console.log('🚀 Payment method sync started', { customer_id, sync_all, limit });

    let results = [];

    if (customer_id) {
      // Sync specific customer
      console.log(`Syncing specific customer: ${customer_id}`);
      const result = await syncCustomerPaymentMethod(customer_id);
      results.push(result);
    } else if (sync_all) {
      // Sync multiple customers with **** payment method data
      console.log(`Syncing up to ${limit} customers with placeholder data...`);
      
      const { data: customers, error } = await supabase
        .from('stripe_orders')
        .select('customer_id')
        .eq('status', 'completed')
        .eq('payment_method_last4', '****')
        .limit(limit);

      if (error) {
        throw new Error(`Failed to fetch customers: ${error.message}`);
      }

      console.log(`Found ${customers?.length || 0} customers to sync`);

      // Process customers in batches to avoid timeouts
      for (const customer of customers || []) {
        const result = await syncCustomerPaymentMethod(customer.customer_id);
        results.push(result);
        
        // Small delay between customers to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    } else {
      return Response.json(
        { error: 'Either customer_id or sync_all=true must be provided' }, 
        { status: 400 }
      );
    }

    const summary = {
      total_processed: results.length,
      successful_syncs: results.filter(r => r.success).length,
      found_real_data: results.filter(r => r.success && r.has_real_data).length,
      errors: results.filter(r => !r.success).length
    };

    console.log('✅ Payment method sync completed', summary);

    return Response.json({
      success: true,
      summary,
      results
    });

  } catch (error) {
    console.error('❌ Payment method sync error:', error);
    return Response.json(
      { error: error.message }, 
      { status: 500 }
    );
  }
}); 