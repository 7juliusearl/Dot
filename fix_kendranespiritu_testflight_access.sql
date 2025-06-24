-- 🔧 FIX TESTFLIGHT ACCESS: kendranespiritu@gmail.com
-- Customer ID: cus_SROKz1r6tv7kzd

-- ========================================
-- 1. FIRST, CHECK CURRENT STATE
-- ========================================
-- Check if stripe_customers record exists
SELECT 
  'CURRENT_STRIPE_CUSTOMERS' as check_type,
  customer_id,
  email,
  user_id,
  payment_type,
  beta_user,
  deleted_at
FROM stripe_customers 
WHERE customer_id = 'cus_SROKz1r6tv7kzd' OR email = 'kendranespiritu@gmail.com';

-- Check auth.users for this email
SELECT 
  'AUTH_USERS_CHECK' as check_type,
  id as user_id,
  email,
  created_at
FROM auth.users 
WHERE email = 'kendranespiritu@gmail.com';

-- ========================================
-- 2. CREATE/UPDATE STRIPE_CUSTOMERS RECORD
-- ========================================
-- Insert or update stripe_customers record to ensure TestFlight access
INSERT INTO stripe_customers (
  customer_id,
  email,
  user_id,
  payment_type,
  beta_user,
  created_at,
  updated_at
)
SELECT 
  'cus_SROKz1r6tv7kzd' as customer_id,
  'kendranespiritu@gmail.com' as email,
  u.id as user_id,
  'monthly' as payment_type,  -- Monthly subscriber
  false as beta_user,
  NOW() as created_at,
  NOW() as updated_at
FROM auth.users u
WHERE u.email = 'kendranespiritu@gmail.com'
ON CONFLICT (customer_id) 
DO UPDATE SET
  email = EXCLUDED.email,
  user_id = EXCLUDED.user_id,
  payment_type = EXCLUDED.payment_type,
  updated_at = NOW(),
  deleted_at = NULL;  -- Ensure not soft deleted

-- ========================================
-- 3. VERIFY THE FIX
-- ========================================
-- Check that stripe_customers record now exists properly
SELECT 
  'VERIFICATION_STRIPE_CUSTOMERS' as check_type,
  sc.customer_id,
  sc.email,
  sc.user_id,
  sc.payment_type,
  sc.beta_user,
  sc.deleted_at,
  u.email as auth_email,
  CASE 
    WHEN sc.user_id IS NOT NULL AND u.id IS NOT NULL THEN '✅ PROPERLY LINKED'
    ELSE '❌ STILL NOT LINKED'
  END as link_status
FROM stripe_customers sc
LEFT JOIN auth.users u ON sc.user_id = u.id
WHERE sc.customer_id = 'cus_SROKz1r6tv7kzd';

-- Check that stripe_orders record is good
SELECT 
  'VERIFICATION_STRIPE_ORDERS' as check_type,
  customer_id,
  email,
  purchase_type,
  status,
  payment_status,
  subscription_status,
  cancel_at_period_end,
  current_period_end,
  TO_TIMESTAMP(current_period_end) as period_end_readable,
  CASE 
    WHEN status = 'completed' 
     AND payment_status = 'paid' 
     AND subscription_status = 'active' 
     AND (cancel_at_period_end = false OR cancel_at_period_end IS NULL)
     AND (current_period_end IS NULL OR current_period_end > EXTRACT(EPOCH FROM NOW()))
    THEN '✅ ORDER QUALIFIES FOR ACCESS'
    ELSE '❌ ORDER ISSUE'
  END as order_status
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd'
  AND status = 'completed'
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 1;

-- ========================================
-- 4. TESTFLIGHT ACCESS SIMULATION
-- ========================================
-- Simulate the exact TestFlight access logic
WITH access_check AS (
  SELECT 
    sc.customer_id,
    sc.email,
    sc.user_id,
    sc.payment_type,
    sc.deleted_at as customer_deleted,
    so.status as order_status,
    so.purchase_type,
    so.subscription_status,
    so.cancel_at_period_end,
    so.current_period_end,
    so.deleted_at as order_deleted,
    EXTRACT(EPOCH FROM NOW()) as current_timestamp
  FROM stripe_customers sc
  LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id 
    AND so.status = 'completed' 
    AND so.deleted_at IS NULL
  WHERE sc.customer_id = 'cus_SROKz1r6tv7kzd'
    AND sc.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1
)
SELECT 
  'TESTFLIGHT_ACCESS_SIMULATION' as check_type,
  customer_id,
  email,
  user_id,
  purchase_type,
  subscription_status,
  cancel_at_period_end,
  current_period_end,
  CASE 
    WHEN customer_deleted IS NOT NULL THEN '❌ FAIL: Customer soft deleted'
    WHEN user_id IS NULL THEN '❌ FAIL: No user_id mapping'
    WHEN order_status IS NULL THEN '❌ FAIL: No completed order found'
    WHEN order_deleted IS NOT NULL THEN '❌ FAIL: Order soft deleted'
    WHEN purchase_type = 'lifetime' AND (subscription_status != 'canceled' OR subscription_status IS NULL) THEN '✅ PASS: Lifetime access'
    WHEN subscription_status = 'active' AND (cancel_at_period_end = false OR cancel_at_period_end IS NULL) THEN '✅ PASS: Active subscription'
    WHEN cancel_at_period_end = true AND current_period_end > current_timestamp THEN '✅ PASS: Canceled but in paid period'
    ELSE '❌ FAIL: Subscription not active - status: ' || COALESCE(subscription_status, 'NULL')
  END as access_result
FROM access_check; 