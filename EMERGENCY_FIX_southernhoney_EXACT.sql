-- 🚨 EMERGENCY FIX: southernhoneyphotography112@gmail.com
-- User paid $27.99 yearly but webhook failed to create order record
-- Price ID: price_1RbnIfInTpoMSXouPdJBHz97

SELECT '🚨 EMERGENCY FIX FOR SOUTHERNHONEYPHOTOGRAPHY112@GMAIL.COM - $27.99 YEARLY' as emergency_fix;

-- Step 1: Verify customer exists
SELECT 
  'CUSTOMER INFO:' as info,
  customer_id,
  user_id,
  email,
  payment_type,
  created_at
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 2: Confirm no existing orders
SELECT 
  'EXISTING ORDERS (should be 0):' as info,
  COUNT(*) as order_count
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 3: Create the missing order record with EXACT details
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
  'cs_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15) as checkout_session_id,
  'pi_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15) as payment_intent_id,
  customer_id,
  2799,  -- $27.99 in cents
  'usd' as currency,
  'paid' as payment_status,
  'completed' as status,
  'yearly' as purchase_type,
  email,
  'sub_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15) as subscription_id,
  'active' as subscription_status,
  'price_1RbnIfInTpoMSXouPdJBHz97' as price_id,  -- EXACT price ID
  EXTRACT(EPOCH FROM NOW())::bigint as current_period_start,
  EXTRACT(EPOCH FROM NOW() + INTERVAL '1 year')::bigint as current_period_end,  -- 1 year from now
  false as cancel_at_period_end,
  'card' as payment_method_brand,
  '****' as payment_method_last4,
  NOW() as created_at,
  NOW() as updated_at
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 4: Verify the order was created
SELECT 
  'ORDER CREATED SUCCESSFULLY:' as info,
  id,
  customer_id,
  amount_total / 100.0 as amount_dollars,
  status,
  purchase_type,
  email,
  subscription_status,
  price_id,
  to_timestamp(current_period_end)::date as expires_on,
  created_at
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Step 5: Test the dashboard query (CRITICAL TEST)
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
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS: User will now see yearly subscription!'
    ELSE '❌ STILL BROKEN: Need more investigation'
  END as result,
  COUNT(*) as matching_orders,
  MAX(purchase_type) as subscription_type,
  MAX(amount_total) / 100.0 as amount_paid,
  MAX(to_timestamp(current_period_end)::date) as expires_on
FROM user_orders;

-- Step 6: Create corresponding subscription record for legacy compatibility
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

-- Step 7: Update customer payment_type if needed
UPDATE stripe_customers 
SET 
  payment_type = 'yearly',
  updated_at = NOW()
WHERE email = 'southernhoneyphotography112@gmail.com'
  AND (payment_type IS NULL OR payment_type != 'yearly');

-- Step 8: Log the emergency fix
INSERT INTO sync_logs (customer_id, operation, status, details)
SELECT 
  customer_id,
  'emergency_fix_missing_yearly_order',
  'completed',
  jsonb_build_object(
    'user_email', 'southernhoneyphotography112@gmail.com',
    'issue', 'webhook_failed_missing_order_record',
    'action', 'manually_created_yearly_order_and_subscription',
    'amount_paid', '$27.99',
    'price_id', 'price_1RbnIfInTpoMSXouPdJBHz97',
    'purchase_type', 'yearly',
    'expires_on', to_timestamp(current_period_end)::date,
    'timestamp', NOW()
  )
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
  AND id = (SELECT MAX(id) FROM stripe_orders WHERE email = 'southernhoneyphotography112@gmail.com');

-- Step 9: Final verification
SELECT 
  'FINAL VERIFICATION:' as final_check,
  sc.email,
  sc.payment_type as customer_type,
  so.purchase_type as order_type,
  so.amount_total / 100.0 as amount_paid,
  so.subscription_status,
  to_timestamp(so.current_period_end)::date as yearly_expires_on,
  CASE 
    WHEN so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN '✅ ACTIVE'
    ELSE '❌ EXPIRED'
  END as status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'southernhoneyphotography112@gmail.com'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL;

SELECT '✅ EMERGENCY FIX COMPLETE!' as result;
SELECT '💰 Customer now has access to $27.99 yearly subscription' as summary;
SELECT '📱 Have customer refresh dashboard or log out/in to see subscription' as instruction;
SELECT '📅 Yearly subscription expires: ' || (NOW() + INTERVAL '1 year')::date as expires; 