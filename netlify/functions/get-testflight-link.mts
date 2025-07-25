import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.VITE_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! // Use service role for admin access
);

export default async (request: Request) => {
  if (request.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Get the authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Verify the JWT token
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Check if user has active subscription and is not deleted
    const { data: customerData, error: customerError } = await supabase
      .from('stripe_customers')
      .select(`
        customer_id,
        email,
        payment_type,
        beta_user,
        deleted_at
      `)
      .eq('user_id', user.id)
      .is('deleted_at', null) // Must not be soft deleted
      .single();

    if (customerError || !customerData) {
      return new Response(JSON.stringify({ 
        error: 'No active subscription found',
        hasAccess: false,
        reason: 'no_subscription'
      }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Check if user has completed payment and get subscription status
    const { data: orderData, error: orderError } = await supabase
      .from('stripe_orders')
      .select('status, purchase_type, subscription_status, cancel_at_period_end, current_period_end, created_at')
      .eq('customer_id', customerData.customer_id)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .single();

    if (orderError || !orderData) {
      return new Response(JSON.stringify({ 
        error: 'No completed payment found',
        hasAccess: false,
        reason: 'no_payment'
      }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Check if user has valid access
    const now = Math.floor(Date.now() / 1000);
    let hasAccess = false;
    let accessReason = '';

    // Helper function to properly handle boolean values from database
    const isCancelAtPeriodEnd = orderData.cancel_at_period_end === true || orderData.cancel_at_period_end === 'true';

    if (orderData.purchase_type === 'lifetime') {
      // Lifetime users always have access unless explicitly canceled
      hasAccess = orderData.subscription_status !== 'canceled';
      accessReason = hasAccess ? 'lifetime_access' : 'lifetime_canceled';
    } else {
      // For subscription users, check various scenarios
      if (orderData.subscription_status === 'active' && !isCancelAtPeriodEnd) {
        // Active subscription, not canceled
        hasAccess = true;
        accessReason = 'active_subscription';
      } else if (isCancelAtPeriodEnd && orderData.current_period_end && orderData.current_period_end > now) {
        // Canceled but still within the paid period
        hasAccess = true;
        accessReason = 'canceled_but_active_until_period_end';
      } else if (orderData.subscription_status === 'canceled' || 
                 orderData.subscription_status === 'unpaid' || 
                 orderData.subscription_status === 'past_due' ||
                 (isCancelAtPeriodEnd && orderData.current_period_end && orderData.current_period_end <= now)) {
        // Truly canceled or expired
        hasAccess = false;
        accessReason = 'subscription_ended';
      } else {
        // Default to checking if subscription is active
        hasAccess = orderData.subscription_status === 'active';
        accessReason = hasAccess ? 'active_subscription' : 'subscription_inactive';
      }
    }

    if (!hasAccess) {
      const errorMessage = accessReason === 'subscription_ended' 
        ? 'Your subscription has ended or been canceled'
        : accessReason === 'lifetime_canceled'
        ? 'Your lifetime access has been canceled'
        : 'Subscription is not active';

      return new Response(JSON.stringify({ 
        error: errorMessage,
        hasAccess: false,
        reason: accessReason,
        status: orderData.subscription_status,
        cancelAtPeriodEnd: orderData.cancel_at_period_end,
        currentPeriodEnd: orderData.current_period_end
      }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // User has access! Return the TestFlight link
    const testFlightLink = "https://testflight.apple.com/join/cGYTUPH1";
    
    return new Response(JSON.stringify({
      hasAccess: true,
      testFlightLink,
      userInfo: {
        email: customerData.email,
        paymentType: customerData.payment_type,
        subscriptionStatus: orderData.subscription_status,
        betaUser: customerData.beta_user
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('TestFlight link error:', error);
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      hasAccess: false,
      reason: 'server_error'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}; 