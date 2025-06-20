-- Remove Canceled Users from TestFlight Access
-- This script helps you identify and soft-delete users who have canceled

-- ===== STEP 1: IDENTIFY CANCELED USERS =====
-- First, let's see who has canceled (useful to identify who to remove)

SELECT 
  '=== USERS TO REMOVE FROM TESTFLIGHT ===' as info,
  sc.email,
  sc.payment_type,
  so.subscription_status,
  sc.created_at,
  CASE 
    WHEN so.subscription_status = 'canceled' THEN '❌ CANCELED'
    WHEN so.subscription_status = 'unpaid' THEN '💳 UNPAID'
    WHEN so.subscription_status = 'past_due' THEN '⏰ PAST DUE'
    ELSE '❓ OTHER'
  END as reason
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.subscription_status IN ('canceled', 'unpaid', 'past_due')
  AND sc.deleted_at IS NULL
  AND so.deleted_at IS NULL
ORDER BY sc.created_at DESC;

-- Alternative: Find users who might have canceled subscriptions
-- (Check if they have any Stripe subscription data that indicates cancellation)
SELECT 
  '=== POTENTIAL CANCELED USERS (Alternative Check) ===' as info,
  email,
  payment_type,
  created_at,
  'CHECK MANUALLY' as action
FROM stripe_customers 
WHERE deleted_at IS NULL
  AND customer_id IN (
    SELECT DISTINCT customer_id 
    FROM stripe_orders 
    WHERE subscription_status IN ('canceled', 'unpaid', 'past_due')
      AND deleted_at IS NULL
  )
ORDER BY created_at DESC;

-- ===== STEP 2: SOFT DELETE SPECIFIC USER =====
-- Replace 'user@example.com' with the actual email of canceled user

DO $$
DECLARE
  user_email text := 'user@example.com'; -- ⚠️ CHANGE THIS EMAIL
  target_customer_id text;
  affected_rows integer;
BEGIN
  -- Get customer ID
  SELECT customer_id INTO target_customer_id
  FROM stripe_customers 
  WHERE email = user_email AND deleted_at IS NULL;
  
  IF target_customer_id IS NULL THEN
    RAISE NOTICE '❌ User % not found or already deleted', user_email;
    RETURN;
  END IF;
  
  -- Soft delete from stripe_customers
  UPDATE stripe_customers 
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id = target_customer_id;
  
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  
  -- Soft delete from stripe_orders  
  UPDATE stripe_orders
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id = target_customer_id;
  
  RAISE NOTICE '✅ Soft deleted user: %', user_email;
  RAISE NOTICE '🚫 User will no longer have TestFlight access';
  RAISE NOTICE '📊 Data preserved for analytics';
END $$;

-- ===== STEP 3: BULK DELETE ALL CANCELED USERS =====
-- ⚠️ UNCOMMENT ONLY IF YOU WANT TO REMOVE ALL CANCELED USERS AT ONCE

/*
DO $$
DECLARE
  deleted_count integer;
BEGIN
  -- Soft delete all canceled users
  UPDATE stripe_customers 
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id IN (
    SELECT DISTINCT sc.customer_id
    FROM stripe_customers sc
    JOIN stripe_orders so ON sc.customer_id = so.customer_id
    WHERE so.subscription_status IN ('canceled', 'unpaid', 'past_due')
      AND sc.deleted_at IS NULL
      AND so.deleted_at IS NULL
  );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- Also soft delete their orders
  UPDATE stripe_orders
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id IN (
    SELECT customer_id FROM stripe_customers 
    WHERE deleted_at IS NOT NULL
  )
  AND deleted_at IS NULL;
  
  RAISE NOTICE '✅ Soft deleted % canceled users', deleted_count;
  RAISE NOTICE '🚫 They will no longer have TestFlight access';
  RAISE NOTICE '📊 All data preserved for analytics';
END $$;
*/

-- ===== STEP 4: VERIFY RESULTS =====
SELECT 
  '=== VERIFICATION: CURRENT ACTIVE USERS ===' as info,
  COUNT(*) as active_users,
  COUNT(CASE WHEN payment_type = 'lifetime' THEN 1 END) as lifetime_users,
  COUNT(CASE WHEN payment_type = 'yearly' THEN 1 END) as yearly_users,
  COUNT(CASE WHEN payment_type = 'monthly' THEN 1 END) as monthly_users
FROM stripe_customers 
WHERE deleted_at IS NULL;

SELECT 
  '=== VERIFICATION: REMOVED USERS ===' as info,
  COUNT(*) as removed_users,
  MIN(deleted_at) as first_removal,
  MAX(deleted_at) as last_removal
FROM stripe_customers 
WHERE deleted_at IS NOT NULL;

-- ===== STEP 5: CHECK SPECIFIC USER'S SUBSCRIPTION STATUS =====
-- Use this to check the status of a specific user before removing them

/*
SELECT 
  '=== USER STATUS CHECK ===' as info,
  sc.email,
  sc.payment_type,
  sc.created_at as customer_created,
  so.subscription_status,
  so.status as order_status,
  so.purchase_type,
  so.created_at as order_created,
  CASE 
    WHEN sc.deleted_at IS NOT NULL THEN '🗑️ ALREADY DELETED'
    WHEN so.subscription_status IN ('canceled', 'unpaid', 'past_due') THEN '❌ SHOULD BE REMOVED'
    WHEN so.status = 'completed' AND so.subscription_status = 'active' THEN '✅ ACTIVE - KEEP'
    ELSE '❓ NEEDS MANUAL REVIEW'
  END as recommendation
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'specific_user@example.com' -- CHANGE THIS EMAIL
ORDER BY so.created_at DESC;
*/

-- ===== RESTORE A USER (IF NEEDED) =====
-- If you accidentally soft-delete someone or they resubscribe

/*
UPDATE stripe_customers 
SET deleted_at = NULL, updated_at = NOW()
WHERE email = 'user_to_restore@example.com';

UPDATE stripe_orders
SET deleted_at = NULL, updated_at = NOW()
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE email = 'user_to_restore@example.com'
);
*/ 