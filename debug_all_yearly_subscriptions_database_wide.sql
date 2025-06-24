-- 🚨 DATABASE-WIDE: Check ALL yearly subscriptions for issues
-- This checks the ENTIRE database, not just recent orders

-- 1. Count all yearly subscriptions
SELECT 
    'YEARLY SUBSCRIPTION OVERVIEW:' as info,
    COUNT(*) as total_yearly_orders,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status != 'completed' THEN 1 END) as incomplete_orders,
    COUNT(CASE WHEN subscription_status = 'active' THEN 1 END) as active_subscriptions,
    COUNT(CASE WHEN subscription_status != 'active' OR subscription_status IS NULL THEN 1 END) as inactive_subscriptions
FROM stripe_orders 
WHERE purchase_type = 'yearly' 
  AND deleted_at IS NULL;

-- 2. Find ALL yearly orders with problems (database-wide)
SELECT 
    'ALL PROBLEMATIC YEARLY ORDERS:' as issue,
    email,
    customer_id,
    status,
    subscription_status,
    payment_status,
    amount_total / 100.0 as amount_paid,
    created_at,
    CASE 
        WHEN status != 'completed' THEN '❌ Order not completed'
        WHEN subscription_status != 'active' OR subscription_status IS NULL THEN '❌ Subscription not active'
        WHEN payment_status != 'paid' THEN '❌ Payment not paid'
        WHEN subscription_id IS NULL THEN '❌ Missing subscription_id'
        WHEN current_period_start IS NULL THEN '❌ Missing period_start'
        WHEN current_period_end IS NULL THEN '❌ Missing period_end'
        ELSE '✅ Looks OK'
    END as problem
FROM stripe_orders 
WHERE purchase_type = 'yearly'
  AND deleted_at IS NULL
  AND (
    status != 'completed'
    OR subscription_status != 'active'
    OR subscription_status IS NULL
    OR payment_status != 'paid'
    OR subscription_id IS NULL
    OR current_period_start IS NULL
    OR current_period_end IS NULL
  )
ORDER BY created_at DESC;

-- 3. Check yearly customers vs their orders (database-wide)
SELECT 
    'YEARLY CUSTOMER VS ORDER MISMATCH:' as issue,
    sc.email,
    sc.customer_id,
    sc.payment_type as customer_payment_type,
    so.purchase_type as order_purchase_type,
    so.status as order_status,
    so.subscription_status,
    CASE 
        WHEN sc.payment_type != 'monthly' THEN '❌ Customer not marked as monthly (yearly constraint)'
        WHEN so.status != 'completed' THEN '❌ Order not completed'
        ELSE '✅ OK'
    END as issue_type
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.purchase_type = 'yearly'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL
  AND (
    sc.payment_type != 'monthly'  -- Yearly should map to monthly due to constraint
    OR so.status != 'completed'
    OR so.subscription_status != 'active'
    OR so.subscription_status IS NULL
  )
ORDER BY so.created_at DESC;

-- 4. Check for yearly orders missing subscription records
SELECT 
    'YEARLY ORDERS MISSING SUBSCRIPTION RECORDS:' as issue,
    so.email,
    so.customer_id,
    so.purchase_type,
    so.status,
    so.subscription_status,
    so.created_at,
    CASE 
        WHEN ss.customer_id IS NULL THEN '❌ No subscription record found'
        WHEN ss.status != 'active' THEN '❌ Subscription record not active'
        ELSE '✅ Has subscription record'
    END as subscription_record_status
FROM stripe_orders so
LEFT JOIN stripe_subscriptions ss ON so.customer_id = ss.customer_id AND ss.deleted_at IS NULL
WHERE so.purchase_type = 'yearly'
  AND so.deleted_at IS NULL
  AND (
    ss.customer_id IS NULL  -- No subscription record
    OR ss.status != 'active'  -- Subscription not active
  )
ORDER BY so.created_at DESC;

-- 5. Summary of all yearly subscription issues
SELECT 
    'YEARLY SUBSCRIPTION ISSUES SUMMARY:' as summary,
    COUNT(CASE WHEN so.status != 'completed' THEN 1 END) as orders_not_completed,
    COUNT(CASE WHEN so.subscription_status != 'active' OR so.subscription_status IS NULL THEN 1 END) as subscriptions_not_active,
    COUNT(CASE WHEN so.payment_status != 'paid' THEN 1 END) as payments_not_paid,
    COUNT(CASE WHEN so.subscription_id IS NULL THEN 1 END) as missing_subscription_ids,
    COUNT(CASE WHEN so.current_period_start IS NULL THEN 1 END) as missing_period_start,
    COUNT(CASE WHEN so.current_period_end IS NULL THEN 1 END) as missing_period_end,
    COUNT(CASE WHEN sc.payment_type != 'monthly' THEN 1 END) as customers_wrong_payment_type,
    COUNT(CASE WHEN ss.customer_id IS NULL THEN 1 END) as missing_subscription_records,
    COUNT(*) as total_yearly_orders_checked
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id AND sc.deleted_at IS NULL
LEFT JOIN stripe_subscriptions ss ON so.customer_id = ss.customer_id AND ss.deleted_at IS NULL
WHERE so.purchase_type = 'yearly'
  AND so.deleted_at IS NULL; 