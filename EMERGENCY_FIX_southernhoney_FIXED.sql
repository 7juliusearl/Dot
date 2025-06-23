-- 🚨 EMERGENCY FIX (CORRECTED): southernhoneyphotography112@gmail.com
-- User paid $27.99 yearly but webhook failed to create order record
-- FIXED: Added missing amount_subtotal and other required fields

SELECT '🚨 EMERGENCY FIX FOR SOUTHERNHONEYPHOTOGRAPHY112@GMAIL.COM - CORRECTED VERSION' as emergency_fix;

-- Create the missing order record with ALL required fields
INSERT INTO stripe_orders (
  checkout_session_id,
  payment_intent_id,
  customer_id,
  amount_subtotal,
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
  'cs_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15),
  'pi_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15),
  customer_id,
  2799,  -- amount_subtotal: $27.99 in cents (same as total for simple case)
  2799,  -- amount_total: $27.99 in cents
  'usd',
  'paid',
  'completed',
  'yearly',
  email,
  'sub_fix_southernhoney_' || SUBSTRING(MD5(customer_id || NOW()::text) FROM 1 FOR 15),
  'active',
  'price_1RbnIfInTpoMSXouPdJBHz97',  -- EXACT price ID
  EXTRACT(EPOCH FROM NOW())::bigint,
  EXTRACT(EPOCH FROM NOW() + INTERVAL '1 year')::bigint,  -- 1 year from now
  false,
  'card',
  '****',
  NOW(),
  NOW()
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- Test the dashboard query to confirm it works
WITH user_orders AS (
  SELECT so.*
  FROM stripe_orders so
  JOIN stripe_customers sc ON so.customer_id = sc.customer_id
  WHERE sc.user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com')
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
)
SELECT 
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS: User will now see yearly subscription!'
    ELSE '❌ STILL BROKEN'
  END as result,
  COUNT(*) as orders_found,
  MAX(amount_total) / 100.0 as amount_paid,
  MAX(purchase_type) as subscription_type,
  MAX(to_timestamp(current_period_end)::date) as expires_on
FROM user_orders;

-- Verify the order was created correctly
SELECT 
  'ORDER VERIFICATION:' as info,
  id,
  email,
  amount_subtotal / 100.0 as subtotal_dollars,
  amount_total / 100.0 as total_dollars,
  purchase_type,
  subscription_status,
  to_timestamp(current_period_end)::date as expires_on
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
ORDER BY created_at DESC
LIMIT 1;

SELECT '✅ EMERGENCY FIX COMPLETE - Customer should now have access!' as result; 