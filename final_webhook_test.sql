-- Final webhook deployment test
-- This verifies memo.gsalinas@gmail.com and the overall system health

SELECT '🚀 FINAL WEBHOOK DEPLOYMENT TEST' as test_title;

-- Test 1: Check memo.gsalinas@gmail.com specifically
SELECT 'TEST 1: MEMO SUBSCRIPTION STATUS' as test;

WITH memo_test AS (
  SELECT 
    so.email,
    so.purchase_type,
    so.amount_total / 100.0 as amount_dollars,
    so.payment_intent_id IS NOT NULL as has_payment_intent,
    so.subscription_id IS NOT NULL as has_subscription_id,
    so.status,
    so.created_at,
    -- Simulate exact dashboard query
    EXISTS (
      SELECT 1 FROM stripe_orders so2
      JOIN stripe_customers sc ON so2.customer_id = sc.customer_id
      JOIN auth.users au ON sc.user_id = au.id
      WHERE au.email = 'memo.gsalinas@gmail.com'
        AND so2.status = 'completed'
        AND so2.deleted_at IS NULL
    ) as will_see_dashboard
  FROM stripe_orders so
  WHERE so.email = 'memo.gsalinas@gmail.com'
    AND so.status = 'completed'
)
SELECT 
  email,
  purchase_type,
  amount_dollars,
  has_payment_intent,
  has_subscription_id,
  CASE 
    WHEN will_see_dashboard THEN '✅ WILL SEE SUBSCRIPTION'
    ELSE '❌ WILL SEE: No Active Subscription'
  END as dashboard_result
FROM memo_test;

-- Test 2: Overall data health after fixes
SELECT 'TEST 2: OVERALL DATA HEALTH' as test;

SELECT 
  COUNT(*) as total_completed_orders,
  SUM(CASE WHEN payment_intent_id IS NULL THEN 1 ELSE 0 END) as null_payment_intents,
  SUM(CASE WHEN subscription_id IS NULL AND purchase_type = 'monthly' THEN 1 ELSE 0 END) as null_monthly_subs,
  SUM(CASE WHEN price_id IS NULL THEN 1 ELSE 0 END) as null_price_ids,
  ROUND(
    (COUNT(*) - SUM(CASE WHEN payment_intent_id IS NULL THEN 1 ELSE 0 END)) * 100.0 / COUNT(*), 
    2
  ) as payment_intent_completion_rate
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

-- Test 3: Sample of users who should now see subscriptions
SELECT 'TEST 3: SAMPLE USER DASHBOARD TEST' as test;

WITH sample_users AS (
  SELECT email 
  FROM stripe_orders 
  WHERE status = 'completed' 
    AND deleted_at IS NULL
    AND email IS NOT NULL
  ORDER BY created_at DESC
  LIMIT 5
),
dashboard_test AS (
  SELECT 
    su.email,
    EXISTS (
      SELECT 1 FROM stripe_orders so
      JOIN stripe_customers sc ON so.customer_id = sc.customer_id
      JOIN auth.users au ON sc.user_id = au.id
      WHERE au.email = su.email
        AND so.status = 'completed'
        AND so.deleted_at IS NULL
    ) as dashboard_works,
    (SELECT COUNT(*) FROM stripe_orders WHERE email = su.email AND status = 'completed') as order_count
  FROM sample_users su
)
SELECT 
  email,
  order_count,
  CASE 
    WHEN dashboard_works THEN '✅ Will see subscription'
    ELSE '❌ Will see: No Active Subscription'
  END as result
FROM dashboard_test;

-- Test 4: Webhook monitoring setup
SELECT 'TEST 4: WEBHOOK MONITORING SETUP' as test;

-- Check if sync_logs table exists and is ready for webhook logging
SELECT 
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Webhook logging ready'
    ELSE '⚠️ Webhook logging table exists but empty'
  END as logging_status,
  COUNT(*) as log_entries
FROM sync_logs;

-- Test 5: Recent webhook activity (if any)
SELECT 'TEST 5: RECENT WEBHOOK ACTIVITY' as test;

SELECT 
  operation,
  status,
  COUNT(*) as count,
  MAX(created_at) as latest
FROM sync_logs 
WHERE created_at > NOW() - INTERVAL '24 hours'
  AND operation LIKE 'webhook_%'
GROUP BY operation, status
ORDER BY latest DESC;

-- Test 6: Critical users from your NULL list
SELECT 'TEST 6: CRITICAL USERS FROM NULL LIST' as test;

WITH critical_users AS (
  SELECT email FROM (VALUES 
    ('memo.gsalinas@gmail.com'),
    ('madicpics@gmail.com'),
    ('davidkeyns@gmail.com'),
    ('candjphotography34@gmail.com'),
    ('crawls.scant-2j@icloud.com')
  ) AS t(email)
)
SELECT 
  cu.email,
  COALESCE(so.purchase_type, 'NOT_FOUND') as purchase_type,
  CASE 
    WHEN so.payment_intent_id IS NOT NULL THEN '✅'
    WHEN so.email IS NULL THEN '❌ NO ORDER'
    ELSE '⚠️ NULL'
  END as payment_intent_status,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM stripe_orders so2
      JOIN stripe_customers sc ON so2.customer_id = sc.customer_id
      JOIN auth.users au ON sc.user_id = au.id
      WHERE au.email = cu.email
        AND so2.status = 'completed'
        AND so2.deleted_at IS NULL
    ) THEN '✅ DASHBOARD WORKS'
    ELSE '❌ NO SUBSCRIPTION VISIBLE'
  END as dashboard_status
FROM critical_users cu
LEFT JOIN stripe_orders so ON cu.email = so.email AND so.status = 'completed'
ORDER BY cu.email;

SELECT '🎉 WEBHOOK DEPLOYMENT TEST COMPLETE!' as result;
SELECT 'Next: Have memo.gsalinas@gmail.com log out and back in to test!' as next_step; 