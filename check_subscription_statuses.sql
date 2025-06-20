-- Check All User Subscription Statuses
-- This helps identify users who canceled but still have access until period end

-- ===== STEP 1: GET COMPLETE USER STATUS OVERVIEW =====
SELECT 
  '=== ALL USER STATUSES OVERVIEW ===' as info,
  sc.email,
  sc.payment_type,
  so.subscription_status,
  so.cancel_at_period_end,
  so.current_period_end,
  CASE 
    WHEN so.current_period_end IS NOT NULL THEN 
      to_timestamp(so.current_period_end)::date
    ELSE NULL
  END as period_end_date,
  CASE 
    WHEN so.cancel_at_period_end = true AND so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 
      '⏰ CANCELED - ACCESS UNTIL ' || to_timestamp(so.current_period_end)::date
    WHEN so.cancel_at_period_end = true AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 
      '❌ CANCELED - ACCESS EXPIRED'
    WHEN so.subscription_status = 'canceled' THEN 
      '❌ CANCELED IMMEDIATELY'
    WHEN so.subscription_status = 'active' AND so.cancel_at_period_end = false THEN 
      '✅ ACTIVE'
    WHEN so.subscription_status = 'unpaid' THEN 
      '💳 UNPAID'
    WHEN so.subscription_status = 'past_due' THEN 
      '⏰ PAST DUE'
    WHEN so.purchase_type = 'lifetime' THEN 
      '♾️ LIFETIME ACCESS'
    ELSE '❓ UNKNOWN STATUS'
  END as access_status,
  sc.created_at as customer_created,
  so.created_at as order_created
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND (so.deleted_at IS NULL OR so.deleted_at IS NULL)
  AND so.status = 'completed'
ORDER BY 
  CASE 
    WHEN so.cancel_at_period_end = true AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 1
    WHEN so.cancel_at_period_end = true AND so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 2
    WHEN so.subscription_status IN ('canceled', 'unpaid', 'past_due') THEN 3
    ELSE 4
  END,
  sc.created_at DESC;

-- ===== STEP 2: USERS WHO CANCELED BUT STILL HAVE ACCESS =====
SELECT 
  '=== CANCELED BUT STILL HAVE ACCESS ===' as info,
  sc.email,
  sc.payment_type,
  so.subscription_status,
  to_timestamp(so.current_period_end)::date as access_expires,
  EXTRACT(DAYS FROM (to_timestamp(so.current_period_end) - NOW())) as days_remaining,
  'WILL LOSE ACCESS ON ' || to_timestamp(so.current_period_end)::date as action_needed
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND so.cancel_at_period_end = true
  AND so.current_period_end > EXTRACT(EPOCH FROM NOW())
ORDER BY so.current_period_end ASC;

-- ===== STEP 3: USERS WHO CANCELED AND ACCESS HAS EXPIRED =====
SELECT 
  '=== CANCELED AND ACCESS EXPIRED - REMOVE IMMEDIATELY ===' as info,
  sc.email,
  sc.payment_type,
  so.subscription_status,
  to_timestamp(so.current_period_end)::date as access_expired,
  EXTRACT(DAYS FROM (NOW() - to_timestamp(so.current_period_end))) as days_expired,
  '🚫 REMOVE TESTFLIGHT ACCESS NOW' as action_needed
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'
  AND (
    (so.cancel_at_period_end = true AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()))
    OR so.subscription_status IN ('canceled', 'unpaid', 'past_due')
  )
ORDER BY so.current_period_end ASC;

-- ===== STEP 4: COUNT SUMMARY =====
SELECT 
  '=== USER COUNT SUMMARY ===' as info,
  COUNT(*) as total_users,
  SUM(CASE WHEN so.subscription_status = 'active' AND so.cancel_at_period_end = false THEN 1 ELSE 0 END) as active_users,
  SUM(CASE WHEN so.cancel_at_period_end = true AND so.current_period_end > EXTRACT(EPOCH FROM NOW()) THEN 1 ELSE 0 END) as canceled_but_active,
  SUM(CASE WHEN so.cancel_at_period_end = true AND so.current_period_end <= EXTRACT(EPOCH FROM NOW()) THEN 1 ELSE 0 END) as canceled_and_expired,
  SUM(CASE WHEN so.purchase_type = 'lifetime' THEN 1 ELSE 0 END) as lifetime_users
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.deleted_at IS NULL 
  AND so.deleted_at IS NULL
  AND so.status = 'completed'; 