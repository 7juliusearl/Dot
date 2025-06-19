-- Debug why kendranespiritu@gmail.com dashboard still shows "No Active Subscription"
-- This will help us understand what data exists and what the dashboard query should return

-- 1. Check if user exists in auth.users
SELECT 'AUTH USER CHECK:' as section, id, email, created_at, email_confirmed_at
FROM auth.users 
WHERE email = 'kendranespiritu@gmail.com';

-- 2. Check stripe_customers table for this user
SELECT 'STRIPE CUSTOMERS:' as section, user_id, customer_id, email, payment_type, beta_user, created_at, deleted_at
FROM stripe_customers 
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR email = 'kendranespiritu@gmail.com';

-- 3. Check ALL orders for this user (this is what dashboard should be reading)
SELECT 'STRIPE ORDERS:' as section, 
       so.customer_id, 
       so.status, 
       so.purchase_type, 
       so.payment_intent_id, 
       so.amount_total,
       so.email,
       so.created_at,
       so.deleted_at,
       sc.user_id
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.email = 'kendranespiritu@gmail.com'
   OR sc.user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
ORDER BY so.created_at DESC;

-- 4. Check what the current dashboard query would return
-- This simulates the exact query the dashboard is now using
WITH user_orders AS (
  SELECT so.*
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1
)
SELECT 'DASHBOARD QUERY RESULT:' as section, *
FROM user_orders;

-- 5. Check stripe_subscriptions table for completeness
SELECT 'STRIPE SUBSCRIPTIONS:' as section, ss.customer_id, ss.subscription_id, ss.status, ss.price_id, ss.created_at, ss.deleted_at, sc.user_id
FROM stripe_subscriptions ss
LEFT JOIN stripe_customers sc ON ss.customer_id = sc.customer_id
WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR ss.customer_id IN (SELECT customer_id FROM stripe_customers WHERE email = 'kendranespiritu@gmail.com');

-- 6. Check if there are any RLS policy issues by checking what an authenticated user would see
-- Simulate what the dashboard query sees with RLS enabled
SELECT 'RLS CHECK - Orders visible to user:' as section, customer_id, status, purchase_type, created_at
FROM stripe_orders
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
    AND deleted_at IS NULL
)
AND status = 'completed'
AND deleted_at IS NULL
ORDER BY created_at DESC;

-- 7. Check recent recovery logs to see if the recovery worked
SELECT 'RECOVERY LOGS:' as section, customer_id, operation, status, details, created_at
FROM sync_logs 
WHERE details->>'user_email' = 'kendranespiritu@gmail.com'
   OR operation LIKE '%recovery%'
ORDER BY created_at DESC
LIMIT 10;
