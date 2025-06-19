-- Diagnostic check for kendranespiritu@gmail.com account recovery status
-- This will help us see what's happening with the account

-- Check if user exists in auth.users
SELECT 'USER CHECK:' as info, id, email, created_at
FROM auth.users 
WHERE email = 'kendranespiritu@gmail.com';

-- Check stripe_customers table
SELECT 'CUSTOMER CHECK:' as info, user_id, customer_id, email, created_at, deleted_at
FROM stripe_customers 
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR email = 'kendranespiritu@gmail.com';

-- Check stripe_subscriptions table
SELECT 'SUBSCRIPTION CHECK:' as info, ss.customer_id, ss.subscription_id, ss.status, ss.price_id, ss.created_at, ss.deleted_at, sc.user_id
FROM stripe_subscriptions ss
LEFT JOIN stripe_customers sc ON ss.customer_id = sc.customer_id
WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR ss.customer_id IN (SELECT customer_id FROM stripe_customers WHERE email = 'kendranespiritu@gmail.com');

-- Check the view that dashboard uses
SELECT 'DASHBOARD VIEW CHECK:' as info, *
FROM stripe_user_subscriptions
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
);

-- Check recent recovery logs
SELECT 'RECOVERY LOGS:' as info, customer_id, operation, status, details, created_at
FROM sync_logs 
WHERE operation LIKE '%recovery%' 
   OR details->>'user_email' = 'kendranespiritu@gmail.com'
ORDER BY created_at DESC
LIMIT 5;

-- Check if there are any RLS policy issues by using service role context
-- This mimics what the dashboard query should return
WITH user_data AS (
  SELECT id as user_id FROM auth.users WHERE email = 'kendranespiritu@gmail.com'
)
SELECT 'RLS SIMULATION:' as info,
    c.customer_id,
    s.subscription_id,
    s.status as subscription_status,
    s.price_id,
    s.current_period_start,
    s.current_period_end,
    s.cancel_at_period_end,
    s.payment_method_brand,
    s.payment_method_last4,
    c.beta_user,
    c.payment_type
FROM stripe_customers c
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
CROSS JOIN user_data u
WHERE c.user_id = u.user_id
  AND c.deleted_at IS NULL
  AND (s.deleted_at IS NULL OR s.deleted_at IS NOT NULL);
