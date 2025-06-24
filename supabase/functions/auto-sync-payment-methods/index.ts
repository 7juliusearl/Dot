import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '', 
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { 
        status: 204,
        headers: corsHeaders 
      });
    }

    console.log('🔄 AUTO-SYNC: Starting automatic payment method sync for recent orders...');

    // Find orders from the last 2 hours with placeholder payment method data
    const { data: ordersNeedingSync, error: queryError } = await supabase
      .from('stripe_orders')
      .select('customer_id, email, created_at, purchase_type')
      .eq('payment_method_last4', '****')
      .eq('status', 'completed')
      .gte('created_at', new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()) // Last 2 hours
      .order('created_at', { ascending: false });

    if (queryError) {
      throw new Error(`Failed to query orders: ${queryError.message}`);
    }

    if (!ordersNeedingSync || ordersNeedingSync.length === 0) {
      console.log('✅ AUTO-SYNC: No recent orders need payment method sync');
      return new Response(JSON.stringify({
        success: true,
        message: 'No orders need syncing',
        orders_checked: 0,
        orders_synced: 0
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`🔍 AUTO-SYNC: Found ${ordersNeedingSync.length} orders needing payment method sync`);

    const syncResults = [];
    let successCount = 0;
    let failCount = 0;

    for (const order of ordersNeedingSync) {
      console.log(`🔄 AUTO-SYNC: Processing ${order.customer_id} (${order.email})`);
      
      try {
        // Call the sync-payment-methods function
        const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/sync-payment-methods`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            action: 'sync_single_customer',
            customer_id: order.customer_id
          })
        });

        if (response.ok) {
          const result = await response.json();
          syncResults.push({
            customer_id: order.customer_id,
            email: order.email,
            success: true,
            result: result
          });
          successCount++;
          console.log(`✅ AUTO-SYNC: Success for ${order.customer_id}`);
        } else {
          const errorText = await response.text();
          syncResults.push({
            customer_id: order.customer_id,
            email: order.email,
            success: false,
            error: `HTTP ${response.status}: ${errorText}`
          });
          failCount++;
          console.error(`❌ AUTO-SYNC: Failed for ${order.customer_id}: HTTP ${response.status}`);
        }

        // Add small delay between requests
        await new Promise(resolve => setTimeout(resolve, 1000));

      } catch (error) {
        syncResults.push({
          customer_id: order.customer_id,
          email: order.email,
          success: false,
          error: error.message
        });
        failCount++;
        console.error(`❌ AUTO-SYNC: Error for ${order.customer_id}:`, error);
      }
    }

    console.log(`🎯 AUTO-SYNC COMPLETE: ${successCount} success, ${failCount} failed`);

    return new Response(JSON.stringify({
      success: true,
      message: `Auto-sync completed`,
      orders_checked: ordersNeedingSync.length,
      orders_synced: successCount,
      orders_failed: failCount,
      success_rate: `${((successCount / ordersNeedingSync.length) * 100).toFixed(1)}%`,
      results: syncResults
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('AUTO-SYNC ERROR:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      message: 'Auto-sync failed'
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
}); 