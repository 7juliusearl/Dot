-- 🔍 COMPREHENSIVE DEBUG: kendranespiritu@gmail.com TestFlight Access Issue
-- Customer ID: cus_SROKz1r6tv7kzd

-- ========================================
-- 1. CHECK STRIPE_CUSTOMERS TABLE
-- ========================================
SELECT 
  'STRIPE_CUSTOMERS' as table_name,
  customer_id,
  email,
  user_id,
  payment_type,
  beta_user,
  deleted_at,
  created_at,
  updated_at
FROM stripe_customers 
WHERE customer_id = 'cus_SROKz1r6tv7kzd' OR email = 'kendranespiritu@gmail.com';

-- ========================================
-- 2. CHECK STRIPE_ORDERS TABLE
-- ========================================
SELECT 
  'STRIPE_ORDERS' as table_name,
  id,
  customer_id,
  email,
  purchase_type,
  status,
  payment_status,
  subscription_status,
  cancel_at_period_end,
  current_period_end,
  subscription_id,
  price_id,
  payment_method_brand,
  payment_method_last4,
  created_at,
  updated_at,
  deleted_at
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd' OR email = 'kendranespiritu@gmail.com'
ORDER BY created_at DESC;

-- ========================================
-- 3. CHECK STRIPE_SUBSCRIPTIONS TABLE
-- ========================================
SELECT 
  'STRIPE_SUBSCRIPTIONS' as table_name,
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
FROM stripe_subscriptions 
WHERE customer_id = 'cus_SROKz1r6tv7kzd'
ORDER BY created_at DESC;

-- ========================================
-- 4. TESTFLIGHT ACCESS LOGIC SIMULATION
-- ========================================
WITH customer_check AS (
  SELECT 
    customer_id,
    email,
    payment_type,
    beta_user,
    deleted_at,
    CASE 
      WHEN deleted_at IS NULL THEN 'PASS: Not deleted'
      ELSE 'FAIL: User is soft deleted'
    END as customer_status
  FROM stripe_customers 
  WHERE customer_id = 'cus_SROKz1r6tv7kzd'
),
order_check AS (
  SELECT 
    customer_id,
    status,
    purchase_type,
    subscription_status,
    cancel_at_period_end,
    current_period_end,
    created_at,
    CASE 
      WHEN status = 'completed' THEN 'PASS: Order completed'
      ELSE 'FAIL: Order not completed - status: ' || status
    END as order_status,
    CASE 
      WHEN deleted_at IS NULL THEN 'PASS: Order not deleted'
      ELSE 'FAIL: Order is soft deleted'
    END as deletion_status
  FROM stripe_orders 
  WHERE customer_id = 'cus_SROKz1r6tv7kzd'
    AND status = 'completed'
    AND deleted_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
),
access_logic AS (
  SELECT 
    o.*,
    c.customer_status,
    o.order_status,
    o.deletion_status,
    EXTRACT(EPOCH FROM NOW()) as current_timestamp,
    CASE 
      WHEN o.purchase_type = 'lifetime' THEN
        CASE 
          WHEN o.subscription_status != 'canceled' OR o.subscription_status IS NULL THEN 'PASS: Lifetime access granted'
          ELSE 'FAIL: Lifetime access canceled'
        END
      WHEN o.subscription_status = 'active' AND (o.cancel_at_period_end = false OR o.cancel_at_period_end IS NULL) THEN 'PASS: Active subscription'
      WHEN o.cancel_at_period_end = true AND o.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 'PASS: Canceled but still in paid period'
      WHEN o.subscription_status IN ('canceled', 'unpaid', 'past_due') THEN 'FAIL: Subscription ended/canceled'
      WHEN o.cancel_at_period_end = true AND o.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 'FAIL: Subscription expired'
      ELSE 'FAIL: Subscription not active - status: ' || COALESCE(o.subscription_status, 'NULL')
    END as access_decision
  FROM order_check o
  CROSS JOIN customer_check c
)
SELECT 
  'ACCESS_LOGIC_RESULT' as table_name,
  customer_id,
  purchase_type,
  subscription_status,
  cancel_at_period_end,
  current_period_end,
  current_timestamp,
  customer_status,
  order_status,
  deletion_status,
  access_decision,
  CASE 
    WHEN access_decision LIKE 'PASS%' THEN '✅ SHOULD HAVE ACCESS'
    ELSE '❌ ACCESS DENIED'
  END as final_result
FROM access_logic;

-- ========================================
-- 5. CHECK IF CURRENT_PERIOD_END IS VALID
-- ========================================
SELECT 
  'PERIOD_END_CHECK' as table_name,
  customer_id,
  current_period_end,
  TO_TIMESTAMP(current_period_end) as period_end_readable,
  NOW() as current_time,
  CASE 
    WHEN current_period_end > EXTRACT(EPOCH FROM NOW()) THEN '✅ Still within paid period'
    ELSE '❌ Past paid period'
  END as period_status
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd'
  AND current_period_end IS NOT NULL; 