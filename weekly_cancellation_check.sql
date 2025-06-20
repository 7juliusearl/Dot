-- Weekly Cancellation Check - Run this every week to catch sync issues
-- This helps identify users who canceled but data didn't sync from Stripe

-- ===== STEP 1: CHECK FOR USERS WHO SHOULD LOSE ACCESS =====
-- Based on current period end dates that have passed

SELECT 
  '=== USERS WHO SHOULD LOSE ACCESS (Period Ended) ===' as info;

SELECT 
  sc.email,
  sc.payment_type,
  so.subscription_status,
  so.cancel_at_period_end,
  to_timestamp(so.current_period_end)::date as access_expired_on,
  EXTRACT(DAYS FROM (NOW() - to_timestamp(so.current_period_end))) as days_since_expired,
  '🚫 REMOVE TESTFLIGHT ACCESS' as action_needed
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND so.cancel_at_period_end = true
  AND so.current_period_end <= EXTRACT(EPOCH FROM NOW())
ORDER BY so.current_period_end ASC;

-- ===== STEP 2: CHECK USERS WITH UPCOMING EXPIRATIONS =====
-- Users who will lose access in the next 7 days

SELECT 
  '=== USERS LOSING ACCESS IN NEXT 7 DAYS ===' as info;

SELECT 
  sc.email,
  sc.payment_type,
  so.subscription_status,
  to_timestamp(so.current_period_end)::date as access_expires_on,
  EXTRACT(DAYS FROM (to_timestamp(so.current_period_end) - NOW())) as days_remaining,
  'WILL LOSE ACCESS SOON' as action_needed
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND so.cancel_at_period_end = true
  AND so.current_period_end > EXTRACT(EPOCH FROM NOW())
  AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()) + (7 * 24 * 60 * 60)
ORDER BY so.current_period_end ASC;

-- ===== STEP 3: REMOVE EXPIRED USERS (AUTO-CLEANUP) =====
-- This automatically removes users whose access has expired

DO $$
DECLARE
  expired_user RECORD;
  removed_count integer := 0;
BEGIN
  FOR expired_user IN 
    SELECT sc.customer_id, sc.email
    FROM stripe_customers sc
    JOIN stripe_orders so ON sc.customer_id = so.customer_id
    WHERE sc.deleted_at IS NULL 
      AND so.deleted_at IS NULL
      AND so.status = 'completed'
      AND so.cancel_at_period_end = true
      AND so.current_period_end <= EXTRACT(EPOCH FROM NOW())
  LOOP
    -- Soft delete expired users
    UPDATE stripe_customers 
    SET deleted_at = NOW(), updated_at = NOW()
    WHERE customer_id = expired_user.customer_id;
    
    UPDATE stripe_orders
    SET deleted_at = NOW(), updated_at = NOW()
    WHERE customer_id = expired_user.customer_id;
    
    removed_count := removed_count + 1;
    RAISE NOTICE '✅ Removed expired user: %', expired_user.email;
  END LOOP;
  
  IF removed_count = 0 THEN
    RAISE NOTICE '✅ No expired users found - all access is current';
  ELSE
    RAISE NOTICE '✅ Removed % expired users total', removed_count;
  END IF;
END $$;

-- ===== STEP 4: SUMMARY REPORT =====
SELECT 
  '=== WEEKLY SUMMARY REPORT ===' as info,
  COUNT(*) as total_active_users,
  SUM(CASE WHEN so.cancel_at_period_end = true AND so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 1 ELSE 0 END) as users_with_pending_cancellation,
  SUM(CASE WHEN so.purchase_type = 'lifetime' THEN 1 ELSE 0 END) as lifetime_users,
  SUM(CASE WHEN so.subscription_status = 'active' AND so.cancel_at_period_end = false THEN 1 ELSE 0 END) as active_monthly_users
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'; 