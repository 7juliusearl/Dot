-- Investigate subscription issue for memo.gsalinas@gmail.com
-- Check all possible locations for this user's data and identify missing fields

SELECT 'INVESTIGATING: memo.gsalinas@gmail.com subscription issue' as info;

-- 1. Check auth.users table
SELECT 
  'AUTH.USERS:' as table_name,
  id,
  email,
  created_at,
  email_confirmed_at
FROM auth.users 
WHERE email = 'memo.gsalinas@gmail.com';

-- 2. Check stripe_customers table
SELECT 
  'STRIPE_CUSTOMERS:' as table_name,
  customer_id,
  user_id,
  email,
  payment_type,
  beta_user,
  created_at,
  deleted_at
FROM stripe_customers 
WHERE email = 'memo.gsalinas@gmail.com'
  OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com');

-- 3. Check stripe_orders table (what Dashboard reads from)
SELECT 
  'STRIPE_ORDERS (DASHBOARD DATA SOURCE):' as table_name,
  id,
  checkout_session_id,
  payment_intent_id,
  customer_id,
  amount_total,
  currency,
  payment_status,
  status,
  purchase_type,
  email,
  subscription_id,
  subscription_status,
  price_id,
  current_period_start,
  current_period_end,
  cancel_at_period_end,
  created_at,
  deleted_at
FROM stripe_orders 
WHERE email = 'memo.gsalinas@gmail.com'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  );

-- 4. Check stripe_subscriptions table (legacy data)
SELECT 
  'STRIPE_SUBSCRIPTIONS (LEGACY):' as table_name,
  customer_id,
  subscription_id,
  status,
  price_id,
  current_period_start,
  current_period_end,
  cancel_at_period_end,
  payment_method_brand,
  payment_method_last4,
  created_at,
  deleted_at
FROM stripe_subscriptions 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  );

-- 5. Dashboard Query Simulation - What user should see
WITH user_orders AS (
  SELECT so.*
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1
)
SELECT 
  'DASHBOARD QUERY RESULT (What user sees):' as info,
  CASE 
    WHEN COUNT(*) > 0 THEN 'USER SHOULD SEE SUBSCRIPTION'
    ELSE 'USER WILL SEE: No Active Subscription'
  END as dashboard_status,
  COUNT(*) as matching_orders,
  MAX(purchase_type) as subscription_type,
  MAX(subscription_status) as current_status,
  MAX(email) as user_email
FROM user_orders;

-- 6. Check for NULL fields in stripe_orders that might cause issues
SELECT 
  'NULL FIELD ANALYSIS:' as info,
  email,
  customer_id,
  COUNT(*) as total_orders,
  SUM(CASE WHEN payment_intent_id IS NULL THEN 1 ELSE 0 END) as null_payment_intent,
  SUM(CASE WHEN subscription_id IS NULL THEN 1 ELSE 0 END) as null_subscription_id,
  SUM(CASE WHEN subscription_status IS NULL THEN 1 ELSE 0 END) as null_subscription_status,
  SUM(CASE WHEN price_id IS NULL THEN 1 ELSE 0 END) as null_price_id,
  SUM(CASE WHEN current_period_start IS NULL THEN 1 ELSE 0 END) as null_period_start,
  SUM(CASE WHEN current_period_end IS NULL THEN 1 ELSE 0 END) as null_period_end
FROM stripe_orders 
WHERE email = 'memo.gsalinas@gmail.com'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  )
GROUP BY email, customer_id;

-- 7. Check recent sync_logs for any errors related to this user
SELECT 
  'SYNC_LOGS (Recent activity):' as table_name,
  customer_id,
  operation,
  status,
  error,
  details,
  created_at
FROM sync_logs 
WHERE (
  details::text ILIKE '%memo.gsalinas@gmail.com%'
  OR details::text ILIKE '%memo%gsalinas%'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  )
)
AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- 8. General analysis of NULL fields across all users
SELECT 
  'GENERAL NULL FIELD ANALYSIS:' as info,
  purchase_type,
  COUNT(*) as total_orders,
  ROUND(AVG(CASE WHEN payment_intent_id IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_payment_intent,
  ROUND(AVG(CASE WHEN subscription_id IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_subscription_id,
  ROUND(AVG(CASE WHEN subscription_status IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_subscription_status,
  ROUND(AVG(CASE WHEN price_id IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_price_id,
  ROUND(AVG(CASE WHEN current_period_start IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_period_start,
  ROUND(AVG(CASE WHEN current_period_end IS NULL THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_null_period_end
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL
GROUP BY purchase_type
ORDER BY purchase_type;

-- 9. Quick fix for memo.gsalinas@gmail.com if data exists but has NULLs
-- This will help identify what needs to be fixed
SELECT 
  'RECOMMENDED ACTION:' as info,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM stripe_orders so
      JOIN stripe_customers sc ON so.customer_id = sc.customer_id
      WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
        AND so.status = 'completed'
        AND so.deleted_at IS NULL
    ) THEN 'User has completed order - check for NULL fields and sync data'
    WHEN EXISTS (
      SELECT 1 FROM stripe_customers 
      WHERE email = 'memo.gsalinas@gmail.com'
        OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
    ) THEN 'User exists but no completed orders found - check Stripe directly'
    ELSE 'User not found in system - may need manual recovery'
  END as action_needed; 