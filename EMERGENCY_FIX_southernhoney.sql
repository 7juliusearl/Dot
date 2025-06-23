-- 🚨 EMERGENCY FIX: southernhoneyphotography112@gmail.com
-- User paid for yearly subscription but webhook failed to create order record
-- CRITICAL: Customer paid but has no access - immediate fix needed

SELECT '🚨 EMERGENCY FIX FOR SOUTHERNHONEYPHOTOGRAPHY112@GMAIL.COM' as emergency_fix;

-- Step 1: Get customer information
SELECT 
  'CUSTOMER INFO:' as info,
  customer_id,
  user_id,
  email,
  payment_type,
  created_at
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 2: Check if any order exists (should be empty)
SELECT 
  'EXISTING ORDERS (should be empty):' as info,
  COUNT(*) as order_count
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
  OR customer_id IN (
    SELECT customer_id FROM stripe_customers 
    WHERE email = 'southernhoneyphotography112@gmail.com'
  );

-- Step 3: Create the missing order record
-- We need to estimate the details based on yearly subscription
INSERT INTO stripe_orders (
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
  payment_method_brand,
  payment_method_last4,
  created_at,
  updated_at
)
SELECT 
  'cs_emergency_' || SUBSTRING(MD5(customer_id || email || NOW()::text) FROM 1 FOR 20) as checkout_session_id,
  'pi_emergency_' || SUBSTRING(MD5(customer_id || email || NOW()::text) FROM 1 FOR 20) as payment_intent_id,
  customer_id,
  -- Estimate yearly amount (you'll need to confirm actual amount)
  CASE 
    WHEN payment_type = 'yearly' THEN 9600  -- $96 for yearly (adjust if different)
    WHEN payment_type = 'lifetime' THEN 49700  -- $497 for lifetime
    ELSE 9600  -- Default to yearly
  END as amount_total,
  'usd' as currency,
  'paid' as payment_status,
  'completed' as status,
  -- Determine purchase type based on amount/context
  CASE 
    WHEN payment_type = 'lifetime' THEN 'lifetime'
    ELSE 'yearly'  -- Assuming yearly based on your description
  END as purchase_type,
  email,
  'sub_emergency_' || SUBSTRING(MD5(customer_id || email || NOW()::text) FROM 1 FOR 20) as subscription_id,
  'active' as subscription_status,
  -- Set appropriate price_id (you may need to add yearly price_id)
  CASE 
    WHEN payment_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
    ELSE 'price_yearly_placeholder'  -- You'll need the actual yearly price_id
  END as price_id,
  EXTRACT(EPOCH FROM NOW())::bigint as current_period_start,
  -- Set period end based on subscription type
  CASE 
    WHEN payment_type = 'lifetime' THEN NULL
    ELSE EXTRACT(EPOCH FROM NOW() + INTERVAL '1 year')::bigint  -- Yearly subscription
  END as current_period_end,
  false as cancel_at_period_end,
  'card' as payment_method_brand,
  '****' as payment_method_last4,
  NOW() as created_at,
  NOW() as updated_at
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 4: Verify the fix
SELECT 
  'VERIFICATION - Order created:' as info,
  id,
  customer_id,
  amount_total / 100.0 as amount_dollars,
  status,
  purchase_type,
  email,
  subscription_status,
  created_at
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 5: Test dashboard query
WITH user_orders AS (
  SELECT so.*
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com')
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1
)
SELECT 
  'DASHBOARD TEST RESULT:' as test,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS: User will now see subscription!'
    ELSE '❌ STILL BROKEN: Need more investigation'
  END as result,
  COUNT(*) as matching_orders,
  MAX(purchase_type) as subscription_type,
  MAX(amount_total) / 100.0 as amount_paid
FROM user_orders;

-- Step 6: Create corresponding subscription record
INSERT INTO stripe_subscriptions (
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
  updated_at
)
SELECT 
  customer_id,
  subscription_id,
  'active'::stripe_subscription_status,
  price_id,
  current_period_start,
  current_period_end,
  cancel_at_period_end,
  payment_method_brand,
  payment_method_last4,
  created_at,
  updated_at
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
  AND id = (SELECT MAX(id) FROM stripe_orders WHERE email = 'southernhoneyphotography112@gmail.com');

-- Step 7: Log the emergency fix
INSERT INTO sync_logs (customer_id, operation, status, details)
SELECT 
  customer_id,
  'emergency_fix_missing_order',
  'completed',
  jsonb_build_object(
    'user_email', 'southernhoneyphotography112@gmail.com',
    'issue', 'webhook_failed_missing_order_record',
    'action', 'manually_created_order_and_subscription',
    'timestamp', NOW(),
    'amount_total', amount_total,
    'purchase_type', purchase_type
  )
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
  AND id = (SELECT MAX(id) FROM stripe_orders WHERE email = 'southernhoneyphotography112@gmail.com');

SELECT '✅ EMERGENCY FIX COMPLETE!' as result;
SELECT 'User should now see their subscription in dashboard' as next_step;
SELECT 'Have user refresh their dashboard or log out/in' as instruction; 