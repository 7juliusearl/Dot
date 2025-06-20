import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

interface UserStatus {
  email: string;
  customer_id: string;
  payment_type: string;
  subscription_status: string;
  cancel_at_period_end: boolean;
  current_period_end: number;
  access_expires_on: string;
  days_remaining: number;
  action_needed: string;
}

Deno.serve(async (req) => {
  try {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    console.log('🔍 Starting subscription monitoring check...');

    // ===== STEP 1: FIND USERS WHO SHOULD LOSE ACCESS =====
    const { data: expiredUsers, error: expiredError } = await supabase
      .from('stripe_customers')
      .select(`
        email,
        customer_id,
        payment_type,
        stripe_orders!inner(
          subscription_status,
          cancel_at_period_end,
          current_period_end,
          status,
          purchase_type
        )
      `)
      .eq('deleted_at', null)
      .eq('stripe_orders.deleted_at', null)
      .eq('stripe_orders.status', 'completed')
      .eq('stripe_orders.cancel_at_period_end', true)
      .lte('stripe_orders.current_period_end', Math.floor(Date.now() / 1000));

    if (expiredError) {
      console.error('Error finding expired users:', expiredError);
      throw expiredError;
    }

    console.log(`Found ${expiredUsers?.length || 0} users with expired access`);

    // ===== STEP 2: FIND USERS LOSING ACCESS SOON =====
    const sevenDaysFromNow = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60);
    const { data: soonToExpireUsers, error: soonError } = await supabase
      .from('stripe_customers')
      .select(`
        email,
        customer_id,
        payment_type,
        stripe_orders!inner(
          subscription_status,
          cancel_at_period_end,
          current_period_end,
          status,
          purchase_type
        )
      `)
      .eq('deleted_at', null)
      .eq('stripe_orders.deleted_at', null)
      .eq('stripe_orders.status', 'completed')
      .eq('stripe_orders.cancel_at_period_end', true)
      .gt('stripe_orders.current_period_end', Math.floor(Date.now() / 1000))
      .lte('stripe_orders.current_period_end', sevenDaysFromNow);

    if (soonError) {
      console.error('Error finding soon-to-expire users:', soonError);
      throw soonError;
    }

    console.log(`Found ${soonToExpireUsers?.length || 0} users losing access in next 7 days`);

    // ===== STEP 3: AUTO-CLEANUP EXPIRED USERS =====
    let removedCount = 0;
    const removedUsers: string[] = [];

    if (expiredUsers && expiredUsers.length > 0) {
      for (const user of expiredUsers) {
        try {
          // Soft delete expired user
          const { error: customerError } = await supabase
            .from('stripe_customers')
            .update({ 
              deleted_at: new Date().toISOString(), 
              updated_at: new Date().toISOString() 
            })
            .eq('customer_id', user.customer_id);

          if (customerError) {
            console.error(`Error deleting customer ${user.email}:`, customerError);
            continue;
          }

          // Soft delete their orders
          const { error: orderError } = await supabase
            .from('stripe_orders')
            .update({ 
              deleted_at: new Date().toISOString(), 
              updated_at: new Date().toISOString() 
            })
            .eq('customer_id', user.customer_id);

          if (orderError) {
            console.error(`Error deleting orders for ${user.email}:`, orderError);
            continue;
          }

          removedCount++;
          removedUsers.push(user.email);
          console.log(`✅ Removed expired user: ${user.email}`);

        } catch (error) {
          console.error(`Error processing user ${user.email}:`, error);
        }
      }
    }

    // ===== STEP 4: GET SUMMARY STATISTICS =====
    const { data: summaryData, error: summaryError } = await supabase
      .from('stripe_customers')
      .select(`
        customer_id,
        stripe_orders!inner(
          subscription_status,
          cancel_at_period_end,
          current_period_end,
          status,
          purchase_type
        )
      `)
      .eq('deleted_at', null)
      .eq('stripe_orders.deleted_at', null)
      .eq('stripe_orders.status', 'completed');

    if (summaryError) {
      console.error('Error getting summary data:', summaryError);
      throw summaryError;
    }

    const summary = {
      total_users: summaryData?.length || 0,
      active_monthly_users: summaryData?.filter(u => 
        u.stripe_orders[0]?.subscription_status === 'active' && 
        u.stripe_orders[0]?.cancel_at_period_end === false &&
        u.stripe_orders[0]?.purchase_type === 'monthly'
      ).length || 0,
      lifetime_users: summaryData?.filter(u => 
        u.stripe_orders[0]?.purchase_type === 'lifetime'
      ).length || 0,
      users_with_pending_cancellation: summaryData?.filter(u => 
        u.stripe_orders[0]?.cancel_at_period_end === true &&
        u.stripe_orders[0]?.current_period_end > Math.floor(Date.now() / 1000)
      ).length || 0
    };

    // ===== STEP 5: PREPARE RESPONSE =====
    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      expired_users_found: expiredUsers?.length || 0,
      expired_users_removed: removedCount,
      removed_users: removedUsers,
      soon_to_expire_users: soonToExpireUsers?.map(user => ({
        email: user.email,
        access_expires_on: new Date(user.stripe_orders[0].current_period_end * 1000).toISOString().split('T')[0],
        days_remaining: Math.ceil((user.stripe_orders[0].current_period_end - Math.floor(Date.now() / 1000)) / (24 * 60 * 60))
      })) || [],
      summary,
      message: removedCount > 0 
        ? `✅ Removed ${removedCount} expired users. ${summary.users_with_pending_cancellation} users have pending cancellations.`
        : `✅ No expired users found. ${summary.users_with_pending_cancellation} users have pending cancellations.`
    };

    console.log('🎯 Monitoring check complete:', response.message);

    return new Response(
      JSON.stringify(response, null, 2),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );

  } catch (error) {
    console.error('Subscription monitoring error:', error);
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
}); 