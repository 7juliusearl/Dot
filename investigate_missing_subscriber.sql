-- Investigate missing subscriber: ali@mossandelder.com
-- Check all possible locations for this user's data

SELECT 'Checking for ali@mossandelder.com in all tables:' as info;

-- 1. Check auth.users table
SELECT 
  'auth.users:' as table_name,
  id,
  email,
  created_at,
  email_confirmed_at
FROM auth.users 
WHERE email = 'ali@mossandelder.com';

-- 2. Check stripe_customers table
SELECT 
  'stripe_customers:' as table_name,
  customer_id,
  user_id,
  email,
  payment_type,
  beta_user,
  created_at,
  deleted_at
FROM stripe_customers 
WHERE email = 'ali@mossandelder.com'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers sc
    JOIN auth.users au ON sc.user_id = au.id
    WHERE au.email = 'ali@mossandelder.com'
  );

-- 3. Check stripe_orders table
SELECT 
  'stripe_orders:' as table_name,
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
  created_at,
  deleted_at
FROM stripe_orders 
WHERE email = 'ali@mossandelder.com'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'ali@mossandelder.com'
  );

-- 4. Check stripe_subscriptions table (might have data)
SELECT 
  'stripe_subscriptions:' as table_name,
  customer_id,
  subscription_id,
  status,
  price_id,
  created_at,
  deleted_at
FROM stripe_subscriptions 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'ali@mossandelder.com'
  );

-- 5. Check sync_logs for any errors related to this user
SELECT 
  'sync_logs (recent errors):' as table_name,
  customer_id,
  operation,
  status,
  error,
  details,
  created_at
FROM sync_logs 
WHERE (
  details::text ILIKE '%ali@mossandelder.com%'
  OR details::text ILIKE '%ali%mossandelder%'
)
AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- 6. Check for any customer_id that might be related to ali
SELECT 
  'Possible related customer_ids:' as info,
  customer_id,
  email,
  created_at
FROM stripe_customers 
WHERE email ILIKE '%ali%' 
   OR email ILIKE '%mossandelder%'
   OR email ILIKE '%moss%elder%';

-- 7. Check recent sync_logs for webhook processing errors
SELECT 
  'Recent webhook/sync errors:' as info,
  operation,
  status,
  error,
  details,
  created_at
FROM sync_logs 
WHERE (
  status = 'error' 
  OR error IS NOT NULL
  OR operation LIKE '%webhook%'
  OR operation LIKE '%checkout%'
)
AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 10; 