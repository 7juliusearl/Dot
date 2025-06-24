-- 🚨 URGENT: Debug yearly subscription not showing as active
-- Find the most recent yearly subscription that might have issues

-- 1. Find the most recent yearly orders
SELECT 
    'RECENT YEARLY ORDERS:' as info,
    so.email,
    so.customer_id,
    so.status,
    so.subscription_status,
    so.purchase_type,
    so.amount_total / 100.0 as amount_paid,
    so.payment_status,
    so.created_at,
    so.current_period_end
FROM stripe_orders so
WHERE so.purchase_type = 'yearly'
  AND so.created_at > NOW() - INTERVAL '2 hours'  -- Recent orders
  AND so.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 10;

-- 2. Check corresponding customer records
SELECT 
    'YEARLY CUSTOMER RECORDS:' as info,
    sc.email,
    sc.customer_id,
    sc.payment_type,
    sc.beta_user,
    sc.created_at
FROM stripe_customers sc
WHERE sc.customer_id IN (
    SELECT so.customer_id 
    FROM stripe_orders so 
    WHERE so.purchase_type = 'yearly' 
      AND so.created_at > NOW() - INTERVAL '2 hours'
      AND so.deleted_at IS NULL
)
AND sc.deleted_at IS NULL
ORDER BY sc.created_at DESC;

-- 3. Check subscription records for yearly users
SELECT 
    'YEARLY SUBSCRIPTION RECORDS:' as info,
    ss.customer_id,
    ss.subscription_id,
    ss.status,
    ss.price_id,
    ss.current_period_start,
    ss.current_period_end,
    ss.cancel_at_period_end,
    ss.created_at
FROM stripe_subscriptions ss
WHERE ss.customer_id IN (
    SELECT so.customer_id 
    FROM stripe_orders so 
    WHERE so.purchase_type = 'yearly' 
      AND so.created_at > NOW() - INTERVAL '2 hours'
      AND so.deleted_at IS NULL
)
AND ss.deleted_at IS NULL
ORDER BY ss.created_at DESC;

-- 4. Check for any yearly orders with problems
SELECT 
    'PROBLEMATIC YEARLY ORDERS:' as issue,
    so.email,
    so.customer_id,
    so.status,
    so.subscription_status,
    so.payment_status,
    CASE 
        WHEN so.status != 'completed' THEN '❌ Order not completed'
        WHEN so.subscription_status != 'active' THEN '❌ Subscription not active'
        WHEN so.payment_status != 'paid' THEN '❌ Payment not paid'
        ELSE '✅ Looks OK'
    END as problem
FROM stripe_orders so
WHERE so.purchase_type = 'yearly'
  AND so.created_at > NOW() - INTERVAL '2 hours'
  AND so.deleted_at IS NULL
  AND (
    so.status != 'completed'
    OR so.subscription_status != 'active'
    OR so.payment_status != 'paid'
  )
ORDER BY so.created_at DESC; 