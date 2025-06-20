-- Debug Canceled Users - Check why dashboard shows different data than database
-- This will help identify the data sync issue

-- ===== CHECK SPECIFIC CANCELED USERS =====
-- Let's look at the exact data for the users who show as canceled in your dashboard

SELECT 
  '=== CHECKING SPECIFIC CANCELED USERS ===' as info;

-- Check each canceled user individually
SELECT 
  'edrxckkrozendijk@gmail.com' as checking_user,
  sc.email,
  sc.customer_id,
  sc.payment_type,
  sc.deleted_at as customer_deleted,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  so.status as order_status,
  so.purchase_type,
  so.deleted_at as order_deleted,
  so.created_at as order_created
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'edrxckkrozendijk@gmail.com'
ORDER BY so.created_at DESC;

SELECT 
  'memo.gsalinas@gmail.com' as checking_user,
  sc.email,
  sc.customer_id,
  sc.payment_type,
  sc.deleted_at as customer_deleted,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  so.status as order_status,
  so.purchase_type,
  so.deleted_at as order_deleted,
  so.created_at as order_created
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'memo.gsalinas@gmail.com'
ORDER BY so.created_at DESC;

SELECT 
  'bsmithphoto10@aol.com' as checking_user,
  sc.email,
  sc.customer_id,
  sc.payment_type,
  sc.deleted_at as customer_deleted,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  so.status as order_status,
  so.purchase_type,
  so.deleted_at as order_deleted,
  so.created_at as order_created
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'bsmithphoto10@aol.com'
ORDER BY so.created_at DESC;

SELECT 
  'leonardstephanie63@gmail.com' as checking_user,
  sc.email,
  sc.customer_id,
  sc.payment_type,
  sc.deleted_at as customer_deleted,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  so.status as order_status,
  so.purchase_type,
  so.deleted_at as order_deleted,
  so.created_at as order_created
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'leonardstephanie63@gmail.com'
ORDER BY so.created_at DESC;

-- ===== CHECK ALL RECORDS WITH CANCEL_AT_PERIOD_END =====
-- This will show us everyone who has cancel_at_period_end = true

SELECT 
  '=== ALL USERS WITH CANCEL_AT_PERIOD_END = TRUE ===' as info;

SELECT 
  sc.email,
  sc.payment_type,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  so.status as order_status,
  so.purchase_type,
  CASE 
    WHEN so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 'STILL ACTIVE'
    WHEN so.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 'EXPIRED'
    ELSE 'NO END DATE'
  END as current_status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.cancel_at_period_end = true
ORDER BY so.current_period_end ASC;

-- ===== CHECK FOR NULL VALUES =====
-- Maybe some users have NULL subscription_status or other issues

SELECT 
  '=== USERS WITH POTENTIAL DATA ISSUES ===' as info;

SELECT 
  sc.email,
  sc.payment_type,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  so.status as order_status,
  CASE 
    WHEN so.subscription_status IS NULL THEN 'NULL_SUBSCRIPTION_STATUS'
    WHEN so.cancel_at_period_end IS NULL THEN 'NULL_CANCEL_FLAG'
    WHEN so.current_period_end IS NULL AND so.purchase_type != 'lifetime' THEN 'NULL_PERIOD_END'
    ELSE 'DATA_LOOKS_OK'
  END as potential_issue
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND sc.email IN (
    'edrxckkrozendijk@gmail.com',
    'memo.gsalinas@gmail.com', 
    'bsmithphoto10@aol.com',
    'leonardstephanie63@gmail.com'
  )
ORDER BY sc.email; 