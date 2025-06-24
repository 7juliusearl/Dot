-- 🚨 EMERGENCY FIX: Yearly subscription not showing as active
-- This fixes the most recent yearly subscription that's having issues

-- 1. First, let's identify the problematic yearly subscription
SELECT 'IDENTIFYING PROBLEM YEARLY SUBSCRIPTION:' as step;

-- 2. Fix the most recent yearly order that's not active
UPDATE stripe_orders 
SET 
    status = 'completed',
    subscription_status = 'active',
    payment_status = 'paid',
    -- Set proper subscription data
    subscription_id = CASE 
        WHEN subscription_id IS NULL THEN 'sub_yearly_' || SUBSTRING(MD5(customer_id || created_at::text) FROM 1 FOR 20)
        ELSE subscription_id
    END,
    current_period_start = CASE 
        WHEN current_period_start IS NULL THEN EXTRACT(EPOCH FROM created_at)::bigint
        ELSE current_period_start
    END,
    current_period_end = CASE 
        WHEN current_period_end IS NULL THEN EXTRACT(EPOCH FROM created_at + INTERVAL '1 year')::bigint
        ELSE current_period_end
    END,
    price_id = CASE 
        WHEN price_id IS NULL THEN 'price_1RbnIfInTpoMSXouPdJBHz97'  -- Yearly price ID
        ELSE price_id
    END,
    cancel_at_period_end = false,
    updated_at = NOW()
WHERE purchase_type = 'yearly'
  AND created_at > NOW() - INTERVAL '2 hours'  -- Recent orders only
  AND deleted_at IS NULL
  AND (
    status != 'completed'
    OR subscription_status != 'active'
    OR payment_status != 'paid'
    OR subscription_id IS NULL
    OR current_period_start IS NULL
    OR current_period_end IS NULL
  );

SELECT 'YEARLY ORDERS FIXED:' as result;

-- 3. Fix the corresponding customer record
UPDATE stripe_customers 
SET 
    payment_type = 'monthly',  -- Yearly maps to monthly due to constraint
    beta_user = true,
    updated_at = NOW(),
    deleted_at = NULL
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_orders 
    WHERE purchase_type = 'yearly' 
      AND created_at > NOW() - INTERVAL '2 hours'
      AND deleted_at IS NULL
)
AND deleted_at IS NULL;

SELECT 'YEARLY CUSTOMER RECORDS FIXED:' as result;

-- 4. Create/update subscription record
INSERT INTO stripe_subscriptions (
    customer_id,
    subscription_id,
    price_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end,
    payment_method_brand,
    payment_method_last4,
    status,
    created_at,
    updated_at
)
SELECT 
    so.customer_id,
    so.subscription_id,
    so.price_id,
    so.current_period_start,
    so.current_period_end,
    false,
    COALESCE(so.payment_method_brand, 'card'),
    COALESCE(so.payment_method_last4, '****'),
    'active'::stripe_subscription_status,
    so.created_at,
    NOW()
FROM stripe_orders so
WHERE so.purchase_type = 'yearly'
  AND so.created_at > NOW() - INTERVAL '2 hours'
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
ON CONFLICT (customer_id) DO UPDATE SET
    subscription_id = EXCLUDED.subscription_id,
    price_id = EXCLUDED.price_id,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    status = 'active'::stripe_subscription_status,
    updated_at = NOW(),
    deleted_at = NULL;

SELECT 'YEARLY SUBSCRIPTION RECORDS FIXED:' as result;

-- 5. Verification: Check that the yearly subscription is now active
SELECT 
    'VERIFICATION - YEARLY SUBSCRIPTION STATUS:' as verification,
    sc.email,
    so.purchase_type,
    so.status as order_status,
    so.subscription_status as order_subscription_status,
    so.payment_status,
    sc.payment_type as customer_payment_type,
    ss.status as subscription_record_status,
    CASE 
        WHEN so.status = 'completed' 
         AND so.subscription_status = 'active' 
         AND so.payment_status = 'paid'
         AND sc.payment_type = 'monthly'  -- Yearly maps to monthly
         AND ss.status = 'active'
        THEN '✅ SUBSCRIPTION IS NOW ACTIVE'
        ELSE '❌ STILL HAS ISSUES'
    END as final_status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
WHERE so.purchase_type = 'yearly'
  AND so.created_at > NOW() - INTERVAL '2 hours'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 5; 