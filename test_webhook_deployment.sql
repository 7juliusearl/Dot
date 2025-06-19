-- Test webhook deployment by checking memo.gsalinas@gmail.com
-- This will verify that the data fix worked and memo should now see their subscription

-- Check memo's current status
SELECT 'MEMO SUBSCRIPTION TEST:' as test;

-- 1. Check if memo exists in stripe_orders (should be YES after data fix)
SELECT 
  'MEMO IN STRIPE_ORDERS:' as status,
  COUNT(*) as found,
  email,
  purchase_type,
  payment_intent_id,
  subscription_id,
  subscription_status,
  status
FROM stripe_orders 
WHERE email = 'memo.gsalinas@gmail.com'
GROUP BY email, purchase_type, payment_intent_id, subscription_id, subscription_status, status;

-- 2. Check if memo exists in stripe_customers (should be linked)
SELECT 
  'MEMO IN STRIPE_CUSTOMERS:' as status,
  COUNT(*) as found,
  email,
  payment_type,
  user_id
FROM stripe_customers 
WHERE email = 'memo.gsalinas@gmail.com'
GROUP BY email, payment_type, user_id;

-- 3. Check if memo exists in auth.users
SELECT 
  'MEMO IN AUTH.USERS:' as status,
  COUNT(*) as found,
  email
FROM auth.users 
WHERE email = 'memo.gsalinas@gmail.com'
GROUP BY email;

-- 4. Simulate the exact Dashboard query for memo
SELECT 'DASHBOARD SIMULATION FOR MEMO:' as test;

WITH user_orders AS (
  SELECT 
    so.id,
    so.email,
    so.customer_id,
    so.status,
    so.purchase_type,
    so.payment_intent_id,
    so.subscription_id,
    so.subscription_status,
    so.price_id,
    so.amount_total,
    so.current_period_start,
    so.current_period_end,
    so.cancel_at_period_end,
    so.created_at
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  JOIN auth.users au ON sc.user_id = au.id
  WHERE au.email = 'memo.gsalinas@gmail.com'
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
)
SELECT 
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ MEMO WILL SEE SUBSCRIPTION'
    ELSE '❌ MEMO WILL SEE: No Active Subscription'
  END as dashboard_result,
  COUNT(*) as active_orders,
  STRING_AGG(purchase_type, ', ') as subscription_types
FROM user_orders;

-- 5. Show memo's complete data if found
SELECT 
  'MEMO COMPLETE DATA:' as info,
  email,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  payment_intent_id,
  subscription_id,
  subscription_status,
  price_id,
  status,
  created_at
FROM stripe_orders 
WHERE email = 'memo.gsalinas@gmail.com'
ORDER BY created_at DESC;

-- 6. Test a few more users from the NULL list to verify fix worked
SELECT 'TESTING OTHER FIXED USERS:' as test;

WITH test_users AS (
  SELECT email FROM (VALUES 
    ('madicpics@gmail.com'),
    ('davidkeyns@gmail.com'),
    ('candjphotography34@gmail.com')
  ) AS t(email)
),
user_dashboard_test AS (
  SELECT 
    tu.email,
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM stripe_orders so
        JOIN stripe_customers sc ON so.customer_id = sc.customer_id
        JOIN auth.users au ON sc.user_id = au.id
        WHERE au.email = tu.email
          AND so.status = 'completed'
          AND so.deleted_at IS NULL
      ) THEN '✅ Will see subscription'
      ELSE '❌ Will see: No Active Subscription'
    END as dashboard_status,
    (SELECT COUNT(*) FROM stripe_orders WHERE email = tu.email AND status = 'completed') as order_count
  FROM test_users tu
)
SELECT * FROM user_dashboard_test;

-- 7. Overall health check
SELECT 
  'OVERALL DATA HEALTH:' as check,
  COUNT(*) as total_completed_orders,
  SUM(CASE WHEN payment_intent_id IS NULL THEN 1 ELSE 0 END) as still_null_payment_intent,
  SUM(CASE WHEN subscription_id IS NULL AND purchase_type = 'monthly' THEN 1 ELSE 0 END) as still_null_subscription_id,
  SUM(CASE WHEN price_id IS NULL THEN 1 ELSE 0 END) as still_null_price_id
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

SELECT '🎉 WEBHOOK DEPLOYMENT TEST COMPLETE!' as result; 