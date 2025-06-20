-- Handle Canceled Users - Multiple Options
-- Choose the approach that best fits your needs

-- ===== QUICK: FIND CANCELED USERS =====
-- First, let's see who has canceled (useful to identify who to remove)

SELECT 'USERS WHO HAVE CANCELED:' as info;
SELECT 
  email,
  payment_type,
  subscription_status,
  created_at,
  'CANDIDATE FOR REMOVAL' as action
FROM stripe_customers 
WHERE subscription_status IN ('canceled', 'unpaid', 'past_due')
  AND deleted_at IS NULL
ORDER BY created_at DESC;

-- ===== OPTION 1: SOFT DELETE (RECOMMENDED) =====
-- Marks users as deleted but keeps data for records
-- They lose access but you keep analytics data

-- Soft delete a specific user by email
DO $$
DECLARE
  user_email text := 'canceled_user@example.com'; -- REPLACE with actual email
  target_customer_id text;
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
  
  -- Soft delete from stripe_orders  
  UPDATE stripe_orders
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE customer_id = target_customer_id;
  
  -- Log the action
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    target_customer_id,
    'user_soft_deleted',
    'completed',
    jsonb_build_object(
      'email', user_email,
      'reason', 'subscription_canceled',
      'action_by', 'admin',
      'timestamp', NOW()
    )
  );
  
  RAISE NOTICE '✅ Soft deleted user: %', user_email;
  RAISE NOTICE '📊 Data preserved for analytics, access revoked';
END $$;

-- ===== BULK SOFT DELETE: ALL CANCELED USERS =====
-- Use this to remove ALL users who have canceled at once

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
  RAISE NOTICE '🚫 They will no longer have beta access';
END $$;
*/

-- ===== OPTION 2: CHANGE STATUS TO CANCELED =====
-- Keeps user but marks subscription as canceled
-- Good for users who might resubscribe

/*
UPDATE stripe_customers 
SET 
  subscription_status = 'canceled',
  updated_at = NOW()
WHERE email = 'canceled_user@example.com'
  AND deleted_at IS NULL;

UPDATE stripe_orders
SET 
  status = 'canceled',
  updated_at = NOW()
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE email = 'canceled_user@example.com'
)
AND deleted_at IS NULL;
*/

-- ===== OPTION 3: HARD DELETE (USE WITH CAUTION) =====
-- Completely removes all data - cannot be undone
-- Only use if legally required or absolutely necessary

/*
DO $$
DECLARE
  user_email text := 'user_to_delete@example.com'; -- REPLACE with actual email
  target_customer_id text;
  target_user_id uuid;
BEGIN
  -- Get IDs
  SELECT customer_id, user_id INTO target_customer_id, target_user_id
  FROM stripe_customers 
  WHERE email = user_email;
  
  IF target_customer_id IS NULL THEN
    RAISE NOTICE '❌ User % not found', user_email;
    RETURN;
  END IF;
  
  -- Log before deletion (for audit trail)
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    target_customer_id,
    'user_hard_deleted',
    'completed',
    jsonb_build_object(
      'email', user_email,
      'customer_id', target_customer_id,
      'user_id', target_user_id,
      'reason', 'hard_delete_requested',
      'action_by', 'admin',
      'timestamp', NOW()
    )
  );
  
  -- Delete from stripe_orders
  DELETE FROM stripe_orders WHERE customer_id = target_customer_id;
  
  -- Delete from stripe_customers  
  DELETE FROM stripe_customers WHERE customer_id = target_customer_id;
  
  -- Optionally delete from auth.users (BE VERY CAREFUL)
  -- DELETE FROM auth.users WHERE id = target_user_id;
  
  RAISE NOTICE '⚠️ HARD DELETED user: %', user_email;
  RAISE NOTICE '🗑️ All data permanently removed';
END $$;
*/

-- ===== VERIFICATION QUERIES =====
-- Check what users are currently active/deleted

-- Show all active users
SELECT 'ACTIVE USERS:' as status;
SELECT 
  email,
  payment_type,
  subscription_status,
  beta_user,
  created_at
FROM stripe_customers 
WHERE deleted_at IS NULL
ORDER BY created_at DESC;

-- Show all soft-deleted users
SELECT 'SOFT DELETED USERS:' as status;
SELECT 
  email,
  payment_type,
  subscription_status,
  deleted_at,
  created_at
FROM stripe_customers 
WHERE deleted_at IS NOT NULL
ORDER BY deleted_at DESC;

-- Count active vs deleted users
SELECT 
  'USER COUNTS:' as info,
  SUM(CASE WHEN deleted_at IS NULL THEN 1 ELSE 0 END) as active_users,
  SUM(CASE WHEN deleted_at IS NOT NULL THEN 1 ELSE 0 END) as deleted_users,
  COUNT(*) as total_users
FROM stripe_customers;

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