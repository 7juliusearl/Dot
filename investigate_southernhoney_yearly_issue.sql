-- URGENT: Investigate southernhoneyphotography112@gmail.com yearly subscription issue
-- User purchased yearly plan but dashboard shows "No Active Subscription"

SELECT 'INVESTIGATING: southernhoneyphotography112@gmail.com YEARLY SUBSCRIPTION ISSUE' as urgent_investigation;

-- ===== STEP 1: CHECK AUTH.USERS =====
SELECT 
  '=== AUTH.USERS CHECK ===' as step,
  id as user_id,
  email,
  created_at,
  email_confirmed_at,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '✅ Email Confirmed'
    ELSE '❌ Email Not Confirmed'
  END as email_status
FROM auth.users 
WHERE email = 'southernhoneyphotography112@gmail.com';

-- ===== STEP 2: CHECK STRIPE_CUSTOMERS =====
SELECT 
  '=== STRIPE_CUSTOMERS CHECK ===' as step,
  customer_id,
  user_id,
  email,
  payment_type,
  beta_user,
  created_at,
  deleted_at,
  CASE 
    WHEN deleted_at IS NOT NULL THEN '❌ DELETED'
    WHEN user_id IS NULL THEN '⚠️ NO USER_ID LINK'
    ELSE '✅ ACTIVE'
  END as customer_status
FROM stripe_customers 
WHERE email = 'southernhoneyphotography112@gmail.com'
  OR user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com');

-- ===== STEP 3: CHECK STRIPE_ORDERS (CRITICAL - DASHBOARD READS FROM HERE) =====
SELECT 
  '=== STRIPE_ORDERS CHECK (DASHBOARD DATA SOURCE) ===' as step,
  id,
  checkout_session_id,
  payment_intent_id,
  customer_id,
  amount_total / 100.0 as amount_dollars,
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
  deleted_at,
  CASE 
    WHEN deleted_at IS NOT NULL THEN '❌ DELETED'
    WHEN status != 'completed' THEN '⚠️ NOT COMPLETED'
    WHEN payment_intent_id IS NULL THEN '⚠️ NULL PAYMENT INTENT'
    WHEN subscription_id IS NULL AND purchase_type = 'monthly' THEN '⚠️ NULL SUBSCRIPTION ID'
    ELSE '✅ LOOKS GOOD'
  END as order_status
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
  OR customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'southernhoneyphotography112@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com')
  )
ORDER BY created_at DESC;

-- ===== STEP 4: SIMULATE EXACT DASHBOARD QUERY =====
SELECT 
  '=== DASHBOARD QUERY SIMULATION ===' as step;

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
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ USER SHOULD SEE SUBSCRIPTION'
    ELSE '❌ USER WILL SEE: No Active Subscription'
  END as dashboard_result,
  COUNT(*) as matching_orders,
  MAX(purchase_type) as subscription_type,
  MAX(subscription_status) as current_status,
  MAX(amount_total) / 100.0 as amount_paid,
  MAX(email) as user_email,
  MAX(created_at) as order_date
FROM user_orders;

-- ===== STEP 5: CHECK FOR YEARLY PLAN PRICE ID =====
SELECT 
  '=== YEARLY PLAN PRICE CHECK ===' as step,
  price_id,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  CASE 
    WHEN price_id = 'price_1RW02UInTpoMSXouhnQLA7Jn' THEN '✅ LIFETIME PRICE'
    WHEN price_id = 'price_1RW01zInTpoMSXoua1wZb9zY' THEN '✅ MONTHLY PRICE'
    WHEN price_id LIKE 'price_%' THEN '⚠️ UNKNOWN PRICE ID - MIGHT BE YEARLY'
    ELSE '❌ NO PRICE ID'
  END as price_analysis,
  created_at
FROM stripe_orders 
WHERE email = 'southernhoneyphotography112@gmail.com'
ORDER BY created_at DESC;

-- ===== STEP 6: CHECK STRIPE_SUBSCRIPTIONS (LEGACY) =====
SELECT 
  '=== STRIPE_SUBSCRIPTIONS CHECK ===' as step,
  customer_id,
  subscription_id,
  status,
  price_id,
  current_period_start,
  current_period_end,
  cancel_at_period_end,
  created_at,
  deleted_at
FROM stripe_subscriptions 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'southernhoneyphotography112@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com')
  )
ORDER BY created_at DESC;

-- ===== STEP 7: CHECK RECENT SYNC LOGS =====
SELECT 
  '=== RECENT SYNC LOGS ===' as step,
  customer_id,
  operation,
  status,
  error,
  details,
  created_at
FROM sync_logs 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'southernhoneyphotography112@gmail.com'
      OR user_id IN (SELECT id FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com')
  )
  OR details::text ILIKE '%southernhoneyphotography112%'
ORDER BY created_at DESC
LIMIT 10;

-- ===== STEP 8: IDENTIFY THE ISSUE =====
SELECT 
  '=== ISSUE DIAGNOSIS ===' as step,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'southernhoneyphotography112@gmail.com') 
      THEN '❌ CRITICAL: User not in auth.users - account creation failed'
    WHEN NOT EXISTS (SELECT 1 FROM stripe_customers WHERE email = 'southernhoneyphotography112@gmail.com') 
      THEN '❌ CRITICAL: User not in stripe_customers - payment processing failed'
    WHEN NOT EXISTS (SELECT 1 FROM stripe_orders WHERE email = 'southernhoneyphotography112@gmail.com' AND status = 'completed') 
      THEN '❌ CRITICAL: No completed order - payment not processed'
    WHEN EXISTS (SELECT 1 FROM stripe_orders WHERE email = 'southernhoneyphotography112@gmail.com' AND status = 'completed' AND deleted_at IS NOT NULL) 
      THEN '❌ CRITICAL: Order exists but is deleted'
    WHEN NOT EXISTS (
      SELECT 1 FROM stripe_orders so
      JOIN stripe_customers sc ON so.customer_id = sc.customer_id
      JOIN auth.users au ON sc.user_id = au.id
      WHERE au.email = 'southernhoneyphotography112@gmail.com'
        AND so.status = 'completed'
        AND so.deleted_at IS NULL
    ) THEN '❌ CRITICAL: Data link broken between auth.users -> stripe_customers -> stripe_orders'
    ELSE '⚠️ Data exists but dashboard query failing - need to investigate further'
  END as primary_issue;

-- ===== STEP 9: SHOW ALL RECENT YEARLY PURCHASES FOR COMPARISON =====
SELECT 
  '=== RECENT YEARLY PURCHASES (For comparison) ===' as step,
  email,
  amount_total / 100.0 as amount_dollars,
  price_id,
  purchase_type,
  status,
  created_at,
  CASE 
    WHEN amount_total >= 10000 THEN '💰 YEARLY AMOUNT'
    WHEN amount_total >= 500 THEN '💰 LIFETIME AMOUNT' 
    ELSE '💰 MONTHLY AMOUNT'
  END as amount_analysis
FROM stripe_orders 
WHERE status = 'completed'
  AND created_at >= NOW() - INTERVAL '7 days'
  AND amount_total >= 5000  -- $50+ (yearly plans are typically higher)
ORDER BY created_at DESC
LIMIT 10; 