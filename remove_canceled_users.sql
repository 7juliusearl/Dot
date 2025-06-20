-- Remove Canceled Users from TestFlight Access
-- This script helps you identify and soft-delete users who have canceled

-- ===== STEP 1: IDENTIFY CANCELED USERS =====
SELECT 
  '=== USERS TO REMOVE FROM TESTFLIGHT ===' as info,
  email,
  payment_type,
  subscription_status,
  created_at,
  CASE 
    WHEN subscription_status = 'canceled' THEN '❌ CANCELED'
    WHEN subscription_status = 'unpaid' THEN '💳 UNPAID'
    WHEN subscription_status = 'past_due' THEN '⏰ PAST DUE'
    ELSE '❓ OTHER'
  END as reason
FROM stripe_customers 
WHERE subscription_status IN ('canceled', 'unpaid', 'past_due')
  AND deleted_at IS NULL
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
  WHERE subscription_status IN ('canceled', 'unpaid', 'past_due')
    AND deleted_at IS NULL;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- Also soft delete their orders
  UPDATE stripe_orders
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id IN (
    SELECT customer_id FROM stripe_customers 
    WHERE subscription_status IN ('canceled', 'unpaid', 'past_due')
      AND deleted_at IS NOT NULL
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