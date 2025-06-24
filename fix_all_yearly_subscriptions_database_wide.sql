-- 🚨 DATABASE-WIDE FIX: Fix ALL yearly subscriptions with issues
-- This fixes ALL yearly subscriptions in the entire database, not just recent ones

SELECT 'STARTING DATABASE-WIDE YEARLY SUBSCRIPTION FIX' as status;

-- 1. Fix ALL yearly orders with issues
UPDATE stripe_orders 
SET 
    status = 'completed',
    subscription_status = 'active',
    payment_status = 'paid',
    -- Generate subscription_id if missing
    subscription_id = CASE 
        WHEN subscription_id IS NULL THEN 'sub_yearly_' || SUBSTRING(MD5(customer_id || created_at::text) FROM 1 FOR 20)
        ELSE subscription_id
    END,
    -- Set period start if missing
    current_period_start = CASE 
        WHEN current_period_start IS NULL THEN EXTRACT(EPOCH FROM created_at)::bigint
        ELSE current_period_start
    END,
    -- Set period end if missing (1 year from start)
    current_period_end = CASE 
        WHEN current_period_end IS NULL THEN EXTRACT(EPOCH FROM created_at + INTERVAL '1 year')::bigint
        ELSE current_period_end
    END,
    -- Set correct yearly price ID
    price_id = CASE 
        WHEN price_id IS NULL THEN 'price_1RbnIfInTpoMSXouPdJBHz97'  -- Yearly price ID
        ELSE price_id
    END,
    cancel_at_period_end = false,
    updated_at = NOW()
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
    OR price_id IS NULL
  );

SELECT 'STEP 1 COMPLETE: Fixed all yearly orders' as status;

-- 2. Fix ALL yearly customer records
UPDATE stripe_customers 
SET 
    payment_type = 'monthly',  -- Yearly maps to monthly due to constraint
    beta_user = true,
    updated_at = NOW(),
    deleted_at = NULL
WHERE customer_id IN (
    SELECT DISTINCT customer_id 
    FROM stripe_orders 
    WHERE purchase_type = 'yearly' 
      AND deleted_at IS NULL
)
AND (
    payment_type != 'monthly'
    OR payment_type IS NULL
    OR beta_user IS NULL
    OR deleted_at IS NOT NULL
);

SELECT 'STEP 2 COMPLETE: Fixed all yearly customer records' as status;

-- 3. Create/update ALL yearly subscription records
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
SELECT DISTINCT
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
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND NOT EXISTS (
    -- Only insert if subscription record doesn't exist
    SELECT 1 FROM stripe_subscriptions ss 
    WHERE ss.customer_id = so.customer_id 
      AND ss.deleted_at IS NULL
  )
ON CONFLICT (customer_id) DO UPDATE SET
    subscription_id = EXCLUDED.subscription_id,
    price_id = EXCLUDED.price_id,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    status = 'active'::stripe_subscription_status,
    payment_method_brand = EXCLUDED.payment_method_brand,
    payment_method_last4 = EXCLUDED.payment_method_last4,
    updated_at = NOW(),
    deleted_at = NULL;

SELECT 'STEP 3 COMPLETE: Created/updated all yearly subscription records' as status;

-- 4. Final verification - show results
SELECT 
    'FINAL VERIFICATION - ALL YEARLY SUBSCRIPTIONS:' as verification,
    COUNT(*) as total_yearly_orders,
    COUNT(CASE WHEN so.status = 'completed' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN so.subscription_status = 'active' THEN 1 END) as active_order_subscriptions,
    COUNT(CASE WHEN so.payment_status = 'paid' THEN 1 END) as paid_orders,
    COUNT(CASE WHEN sc.payment_type = 'monthly' THEN 1 END) as customers_marked_monthly,
    COUNT(CASE WHEN ss.status = 'active' THEN 1 END) as active_subscription_records,
    COUNT(CASE WHEN 
        so.status = 'completed' 
        AND so.subscription_status = 'active' 
        AND so.payment_status = 'paid'
        AND sc.payment_type = 'monthly'
        AND ss.status = 'active'
    THEN 1 END) as fully_fixed_subscriptions
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id AND sc.deleted_at IS NULL
LEFT JOIN stripe_subscriptions ss ON so.customer_id = ss.customer_id AND ss.deleted_at IS NULL
WHERE so.purchase_type = 'yearly'
  AND so.deleted_at IS NULL;

-- 5. Show any remaining issues (should be zero)
SELECT 
    'REMAINING ISSUES (SHOULD BE EMPTY):' as check,
    so.email,
    so.customer_id,
    so.status,
    so.subscription_status,
    so.payment_status,
    sc.payment_type,
    ss.status as subscription_record_status,
    'Still has issues' as problem
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id AND sc.deleted_at IS NULL
LEFT JOIN stripe_subscriptions ss ON so.customer_id = ss.customer_id AND ss.deleted_at IS NULL
WHERE so.purchase_type = 'yearly'
  AND so.deleted_at IS NULL
  AND NOT (
    so.status = 'completed' 
    AND so.subscription_status = 'active' 
    AND so.payment_status = 'paid'
    AND sc.payment_type = 'monthly'
    AND ss.status = 'active'
  )
ORDER BY so.created_at DESC;

SELECT '🎉 DATABASE-WIDE YEARLY SUBSCRIPTION FIX COMPLETE!' as final_status; 