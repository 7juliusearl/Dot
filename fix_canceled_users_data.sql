-- Fix Canceled Users Data - Handle the specific cases identified
-- This will update the database to match the actual Stripe status

-- ===== CASE 1: Fix bsmithphoto10@aol.com - Canceled, ends July 6th =====
DO $$
DECLARE
  user_email text := 'bsmithphoto10@aol.com';
  target_customer_id text;
  july_6th_timestamp bigint := 1751875200; -- July 6, 2025 midnight UTC (approximate)
BEGIN
  SELECT customer_id INTO target_customer_id
  FROM stripe_customers 
  WHERE email = user_email AND deleted_at IS NULL;
  
  IF target_customer_id IS NULL THEN
    RAISE NOTICE '❌ User % not found', user_email;
  ELSE
    -- Update the order to reflect cancellation with July 6th end date
    UPDATE stripe_orders
    SET 
      cancel_at_period_end = true,
      current_period_end = july_6th_timestamp,
      updated_at = NOW()
    WHERE customer_id = target_customer_id
      AND status = 'completed'
      AND deleted_at IS NULL;
    
    -- Check if their access has expired (July 6th has passed)
    IF EXTRACT(EPOCH FROM NOW()) > july_6th_timestamp THEN
      -- Soft delete - access has expired
      UPDATE stripe_customers 
      SET deleted_at = NOW(), updated_at = NOW()
      WHERE customer_id = target_customer_id;
      
      UPDATE stripe_orders
      SET deleted_at = NOW(), updated_at = NOW()
      WHERE customer_id = target_customer_id;
      
      RAISE NOTICE '✅ Removed expired user: % (access ended July 6th)', user_email;
    ELSE
      RAISE NOTICE '⏰ Updated cancellation data for %. Access until July 6th', user_email;
    END IF;
  END IF;
END $$;

-- ===== CASE 2: Fix memo.gsalinas@gmail.com - Canceled, ends July 6th =====
DO $$
DECLARE
  user_email text := 'memo.gsalinas@gmail.com';
  target_customer_id text;
  july_6th_timestamp bigint := 1751875200; -- July 6, 2025 midnight UTC (approximate)
BEGIN
  SELECT customer_id INTO target_customer_id
  FROM stripe_customers 
  WHERE email = user_email AND deleted_at IS NULL;
  
  IF target_customer_id IS NULL THEN
    RAISE NOTICE '❌ User % not found', user_email;
  ELSE
    -- Update the order to reflect cancellation with July 6th end date
    UPDATE stripe_orders
    SET 
      cancel_at_period_end = true,
      current_period_end = july_6th_timestamp,
      updated_at = NOW()
    WHERE customer_id = target_customer_id
      AND status = 'completed'
      AND deleted_at IS NULL;
    
    -- Check if their access has expired (July 6th has passed)
    IF EXTRACT(EPOCH FROM NOW()) > july_6th_timestamp THEN
      -- Soft delete - access has expired
      UPDATE stripe_customers 
      SET deleted_at = NOW(), updated_at = NOW()
      WHERE customer_id = target_customer_id;
      
      UPDATE stripe_orders
      SET deleted_at = NOW(), updated_at = NOW()
      WHERE customer_id = target_customer_id;
      
      RAISE NOTICE '✅ Removed expired user: % (access ended July 6th)', user_email;
    ELSE
      RAISE NOTICE '⏰ Updated cancellation data for %. Access until July 6th', user_email;
    END IF;
  END IF;
END $$;

-- ===== CASE 3: Clean up edrxckkrozendijk@gmail.com - Upgraded to Lifetime =====
DO $$
DECLARE
  user_email text := 'edrxckkrozendijk@gmail.com';
  target_customer_id text;
BEGIN
  SELECT customer_id INTO target_customer_id
  FROM stripe_customers 
  WHERE email = user_email AND deleted_at IS NULL;
  
  IF target_customer_id IS NULL THEN
    RAISE NOTICE '❌ User % not found', user_email;
  ELSE
    -- Soft delete the old monthly subscription record (the one with NULL status)
    UPDATE stripe_orders
    SET deleted_at = NOW(), updated_at = NOW()
    WHERE customer_id = target_customer_id
      AND subscription_status IS NULL
      AND deleted_at IS NULL;
    
    -- Ensure the current record shows lifetime access
    UPDATE stripe_orders
    SET 
      purchase_type = 'lifetime',
      subscription_status = 'active',
      cancel_at_period_end = false,
      current_period_end = NULL, -- Lifetime has no end
      updated_at = NOW()
    WHERE customer_id = target_customer_id
      AND subscription_status = 'active'
      AND deleted_at IS NULL;
    
    -- Update customer record to lifetime
    UPDATE stripe_customers
    SET 
      payment_type = 'lifetime',
      updated_at = NOW()
    WHERE customer_id = target_customer_id;
    
    RAISE NOTICE '✅ Updated % to lifetime access (cleaned up old monthly subscription)', user_email;
  END IF;
END $$;

-- ===== VERIFICATION: Check the results =====
SELECT 
  '=== VERIFICATION: Updated User Statuses ===' as info;

SELECT 
  sc.email,
  sc.payment_type,
  so.subscription_status,
  so.cancel_at_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as access_expires,
  so.purchase_type,
  CASE 
    WHEN sc.deleted_at IS NOT NULL THEN '🗑️ DELETED (No Access)'
    WHEN so.purchase_type = 'lifetime' THEN '♾️ LIFETIME ACCESS'
    WHEN so.cancel_at_period_end = true AND so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 
      '⏰ CANCELED - ACCESS UNTIL ' || to_timestamp(so.current_period_end)::date
    WHEN so.cancel_at_period_end = true AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 
      '❌ CANCELED - ACCESS EXPIRED'
    WHEN so.subscription_status = 'active' THEN '✅ ACTIVE'
    ELSE '❓ UNKNOWN'
  END as current_status
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email IN (
  'bsmithphoto10@aol.com',
  'memo.gsalinas@gmail.com', 
  'edrxckkrozendijk@gmail.com',
  'leonardstephanie63@gmail.com'
)
AND (so.deleted_at IS NULL OR so.deleted_at IS NOT NULL)
ORDER BY sc.email, so.created_at DESC; 