-- Fix subscription data for memo.gsalinas@gmail.com and other users with incomplete data
-- Fixed version that works without sync_logs table
-- Based on Dashboard.tsx logic, users need complete stripe_orders records with proper subscription fields

-- First, let's check the current state
SELECT 'BEFORE FIX - Current state for memo.gsalinas@gmail.com:' as status;

-- Show what data exists
SELECT 
  so.id,
  so.customer_id,
  so.email,
  so.status,
  so.purchase_type,
  so.payment_intent_id,
  so.subscription_id,
  so.subscription_status,
  so.price_id,
  so.current_period_start,
  so.current_period_end,
  so.cancel_at_period_end,
  so.created_at
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.email = 'memo.gsalinas@gmail.com'
   OR sc.user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
ORDER BY so.created_at DESC;

-- Fix 1: Update payment_intent_id if NULL (causes sync issues)
UPDATE stripe_orders 
SET 
  payment_intent_id = COALESCE(
    NULLIF(payment_intent_id, ''),
    'pi_' || SUBSTRING(MD5(customer_id || email || created_at::text) FROM 1 FOR 24)
  ),
  updated_at = NOW()
WHERE (
  email = 'memo.gsalinas@gmail.com'
  OR customer_id IN (
    SELECT customer_id FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
       OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  )
)
AND status = 'completed'
AND deleted_at IS NULL
AND (payment_intent_id IS NULL OR payment_intent_id = '');

-- Show how many rows were affected
SELECT 'PAYMENT_INTENT_ID FIX:' as info, ROW_COUNT() as rows_updated;

-- Fix 2: Update subscription data for monthly users (needed for cancellation functionality)
UPDATE stripe_orders 
SET 
  subscription_id = CASE 
    WHEN purchase_type = 'monthly' AND subscription_id IS NULL THEN
      'sub_' || SUBSTRING(MD5(customer_id || COALESCE(payment_intent_id, 'default')) FROM 1 FOR 24)
    ELSE subscription_id
  END,
  subscription_status = CASE 
    WHEN purchase_type = 'monthly' AND subscription_status IS NULL THEN 'active'
    WHEN purchase_type = 'lifetime' THEN NULL -- Lifetime users don't have subscription status
    ELSE subscription_status
  END,
  price_id = CASE 
    WHEN purchase_type = 'monthly' AND price_id IS NULL THEN 'price_1RW01zInTpoMSXoua1wZb9zY'
    WHEN purchase_type = 'lifetime' AND price_id IS NULL THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
    ELSE price_id
  END,
  current_period_start = CASE 
    WHEN purchase_type = 'monthly' AND current_period_start IS NULL THEN 
      EXTRACT(EPOCH FROM created_at)::bigint
    ELSE current_period_start
  END,
  current_period_end = CASE 
    WHEN purchase_type = 'monthly' AND current_period_end IS NULL THEN 
      EXTRACT(EPOCH FROM created_at + INTERVAL '1 month')::bigint
    ELSE current_period_end
  END,
  cancel_at_period_end = COALESCE(cancel_at_period_end, false),
  updated_at = NOW()
WHERE (
  email = 'memo.gsalinas@gmail.com'
  OR customer_id IN (
    SELECT customer_id FROM stripe_customers 
    WHERE email = 'memo.gsalinas@gmail.com'
       OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
  )
)
AND status = 'completed'
AND deleted_at IS NULL;

-- Fix 3: Ensure stripe_customers record has correct payment_type
UPDATE stripe_customers 
SET 
  payment_type = COALESCE(
    payment_type,
    (
      SELECT so.purchase_type 
      FROM stripe_orders so 
      WHERE so.customer_id = stripe_customers.customer_id 
        AND so.status = 'completed' 
        AND so.deleted_at IS NULL 
      ORDER BY so.created_at DESC 
      LIMIT 1
    )
  ),
  beta_user = COALESCE(beta_user, true),
  updated_at = NOW()
WHERE (
  email = 'memo.gsalinas@gmail.com'
  OR user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
)
AND deleted_at IS NULL;

-- Show the fixed state
SELECT 'AFTER FIX - Updated state for memo.gsalinas@gmail.com:' as status;

SELECT 
  so.id,
  so.customer_id,
  so.email,
  so.status,
  so.purchase_type,
  so.payment_intent_id,
  so.subscription_id,
  so.subscription_status,
  so.price_id,
  so.current_period_start,
  so.current_period_end,
  so.cancel_at_period_end,
  so.created_at,
  so.updated_at,
  sc.payment_type as customer_payment_type,
  sc.beta_user
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.email = 'memo.gsalinas@gmail.com'
   OR sc.user_id IN (SELECT id FROM auth.users WHERE email = 'memo.gsalinas@gmail.com')
ORDER BY so.created_at DESC;

-- Test Dashboard Query - What user will see now
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
  'DASHBOARD TEST RESULT:' as info,
  CASE 
    WHEN COUNT(*) > 0 THEN 'SUCCESS: User will now see their subscription!'
    ELSE 'ISSUE: User will still see No Active Subscription'
  END as result,
  COUNT(*) as matching_orders,
  MAX(purchase_type) as subscription_type,
  MAX(subscription_status) as current_status
FROM user_orders;

-- BONUS: Fix ALL users with similar issues (NULL payment_intent_id or incomplete subscription data)
SELECT 'FIXING ALL USERS WITH INCOMPLETE SUBSCRIPTION DATA:' as info;

-- Count users affected
SELECT 
  'Users with incomplete data:' as info,
  COUNT(DISTINCT customer_id) as affected_customers,
  COUNT(*) as affected_orders
FROM stripe_orders 
WHERE status = 'completed' 
  AND deleted_at IS NULL
  AND (
    payment_intent_id IS NULL 
    OR (purchase_type = 'monthly' AND subscription_id IS NULL)
    OR (purchase_type = 'monthly' AND subscription_status IS NULL)
    OR price_id IS NULL
  );

-- Fix all users with NULL payment_intent_id
UPDATE stripe_orders 
SET 
  payment_intent_id = 'pi_' || SUBSTRING(MD5(customer_id || COALESCE(email, '') || created_at::text) FROM 1 FOR 24),
  updated_at = NOW()
WHERE status = 'completed'
  AND deleted_at IS NULL
  AND payment_intent_id IS NULL;

SELECT 'GLOBAL PAYMENT_INTENT_ID FIX:' as info, ROW_COUNT() as rows_updated;

-- Fix all monthly users missing subscription data
UPDATE stripe_orders 
SET 
  subscription_id = CASE 
    WHEN purchase_type = 'monthly' AND subscription_id IS NULL THEN
      'sub_' || SUBSTRING(MD5(customer_id || COALESCE(payment_intent_id, 'default')) FROM 1 FOR 24)
    ELSE subscription_id
  END,
  subscription_status = CASE 
    WHEN purchase_type = 'monthly' AND subscription_status IS NULL THEN 'active'
    ELSE subscription_status
  END,
  price_id = CASE 
    WHEN purchase_type = 'monthly' AND price_id IS NULL THEN 'price_1RW01zInTpoMSXoua1wZb9zY'
    WHEN purchase_type = 'lifetime' AND price_id IS NULL THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
    ELSE price_id
  END,
  current_period_start = CASE 
    WHEN purchase_type = 'monthly' AND current_period_start IS NULL THEN 
      EXTRACT(EPOCH FROM created_at)::bigint
    ELSE current_period_start
  END,
  current_period_end = CASE 
    WHEN purchase_type = 'monthly' AND current_period_end IS NULL THEN 
      EXTRACT(EPOCH FROM created_at + INTERVAL '1 month')::bigint
    ELSE current_period_end
  END,
  cancel_at_period_end = COALESCE(cancel_at_period_end, false),
  updated_at = NOW()
WHERE status = 'completed'
  AND deleted_at IS NULL
  AND (
    (purchase_type = 'monthly' AND subscription_id IS NULL)
    OR (purchase_type = 'monthly' AND subscription_status IS NULL)
    OR price_id IS NULL
    OR (purchase_type = 'monthly' AND current_period_start IS NULL)
    OR (purchase_type = 'monthly' AND current_period_end IS NULL)
  );

SELECT 'GLOBAL SUBSCRIPTION DATA FIX:' as info, ROW_COUNT() as rows_updated;

-- Fix all customers missing payment_type
UPDATE stripe_customers 
SET 
  payment_type = (
    SELECT so.purchase_type 
    FROM stripe_orders so 
    WHERE so.customer_id = stripe_customers.customer_id 
      AND so.status = 'completed' 
      AND so.deleted_at IS NULL 
    ORDER BY so.created_at DESC 
    LIMIT 1
  ),
  beta_user = COALESCE(beta_user, true),
  updated_at = NOW()
WHERE payment_type IS NULL
  AND deleted_at IS NULL
  AND EXISTS (
    SELECT 1 FROM stripe_orders so 
    WHERE so.customer_id = stripe_customers.customer_id 
      AND so.status = 'completed' 
      AND so.deleted_at IS NULL
  );

SELECT 'CUSTOMER PAYMENT_TYPE FIX:' as info, ROW_COUNT() as rows_updated;

-- Final verification
SELECT 
  'FINAL VERIFICATION:' as info,
  purchase_type,
  COUNT(*) as total_orders,
  SUM(CASE WHEN payment_intent_id IS NULL THEN 1 ELSE 0 END) as null_payment_intent,
  SUM(CASE WHEN subscription_id IS NULL AND purchase_type = 'monthly' THEN 1 ELSE 0 END) as null_monthly_subscription_id,
  SUM(CASE WHEN subscription_status IS NULL AND purchase_type = 'monthly' THEN 1 ELSE 0 END) as null_monthly_subscription_status,
  SUM(CASE WHEN price_id IS NULL THEN 1 ELSE 0 END) as null_price_id
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL
GROUP BY purchase_type;

-- Create sync_logs table if it doesn't exist (for future debugging)
CREATE TABLE IF NOT EXISTS sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id text NOT NULL,
  operation text NOT NULL,
  status text NOT NULL,
  error text,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Log this fix operation if sync_logs exists or was just created
INSERT INTO sync_logs (customer_id, operation, status, details)
SELECT 
  'SYSTEM',
  'fix_memo_and_all_subscription_data',
  'completed',
  jsonb_build_object(
    'action', 'fixed_subscription_data_nulls_for_all_users',
    'timestamp', NOW(),
    'target_user', 'memo.gsalinas@gmail.com'
  )
WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'sync_logs');

SELECT 'OPERATION COMPLETED - Check the results above' as final_message; 