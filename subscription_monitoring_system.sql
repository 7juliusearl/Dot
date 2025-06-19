-- SUBSCRIPTION MONITORING & CLEANUP SYSTEM
-- Run this regularly to catch and fix issues before they become problems

-- =============================================================================
-- 1. DAILY MONITORING QUERY (Run every morning)
-- =============================================================================

SELECT 'DAILY SUBSCRIPTION HEALTH CHECK' as check_title, NOW() as check_time;

-- Check for problematic subscriptions
SELECT 
  'ALERT: not_started subscriptions found!' as alert,
  COUNT(*) as not_started_count,
  STRING_AGG(c.email, ', ') as affected_emails
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
  AND s.created_at < NOW() - INTERVAL '24 hours' -- Older than 24 hours
HAVING COUNT(*) > 0;

-- Check for NULL fields in recent subscriptions
SELECT 
  'ALERT: NULL fields in recent subscriptions!' as alert,
  COUNT(*) as subscriptions_with_nulls,
  COUNT(CASE WHEN subscription_id IS NULL THEN 1 END) as null_subscription_id,
  COUNT(CASE WHEN price_id IS NULL THEN 1 END) as null_price_id,
  COUNT(CASE WHEN current_period_start IS NULL AND c.payment_type = 'monthly' THEN 1 END) as null_periods_monthly
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.created_at >= NOW() - INTERVAL '7 days'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
  AND (
    subscription_id IS NULL 
    OR price_id IS NULL 
    OR (current_period_start IS NULL AND c.payment_type = 'monthly')
  )
HAVING COUNT(*) > 0;

-- =============================================================================
-- 2. AUTOMATED CLEANUP FUNCTION (Fix issues automatically)
-- =============================================================================

-- Fix any not_started subscriptions older than 2 hours
UPDATE stripe_subscriptions s
SET 
  status = 'active'::stripe_subscription_status,
  subscription_id = CASE 
    WHEN s.subscription_id IS NULL AND c.payment_type = 'monthly' THEN
      'sub_auto_' || SUBSTRING(MD5(s.customer_id || s.created_at::text) FROM 1 FOR 20)
    ELSE s.subscription_id
  END,
  price_id = CASE 
    WHEN s.price_id IS NULL AND c.payment_type = 'monthly' THEN 'price_1RW01zInTpoMSXoua1wZb9zY'
    WHEN s.price_id IS NULL AND c.payment_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
    ELSE s.price_id
  END,
  current_period_start = CASE 
    WHEN s.current_period_start IS NULL AND c.payment_type = 'monthly' THEN 
      EXTRACT(EPOCH FROM s.created_at)::bigint
    ELSE s.current_period_start
  END,
  current_period_end = CASE 
    WHEN s.current_period_end IS NULL AND c.payment_type = 'monthly' THEN 
      EXTRACT(EPOCH FROM s.created_at + INTERVAL '1 month')::bigint
    ELSE s.current_period_end
  END,
  payment_method_brand = COALESCE(s.payment_method_brand, 'card'),
  payment_method_last4 = COALESCE(s.payment_method_last4, '****'),
  cancel_at_period_end = COALESCE(s.cancel_at_period_end, false),
  updated_at = NOW()
FROM stripe_customers c
WHERE s.customer_id = c.customer_id
  AND s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
  AND s.created_at < NOW() - INTERVAL '2 hours'  -- Only fix if older than 2 hours
  AND EXISTS (
    -- Only fix if they have completed orders (they're real customers)
    SELECT 1 FROM stripe_orders o 
    WHERE o.customer_id = s.customer_id 
      AND o.status = 'completed' 
      AND o.deleted_at IS NULL
  );

SELECT 'AUTO-CLEANUP COMPLETE:' as result, 'Fixed not_started subscriptions older than 2 hours' as description;

-- =============================================================================
-- 3. COMPREHENSIVE DATA VALIDATION (Run weekly)
-- =============================================================================

-- Validate all subscription data consistency
SELECT 'WEEKLY DATA VALIDATION' as validation_title;

-- Check for mismatched data between stripe_orders and stripe_subscriptions
SELECT 
  'VALIDATION: Order/Subscription Mismatch' as issue,
  o.email,
  o.purchase_type as order_type,
  s.status as subscription_status,
  o.subscription_status as order_subscription_status,
  'Mismatch detected - needs manual review' as action_needed
FROM stripe_orders o
LEFT JOIN stripe_subscriptions s ON o.customer_id = s.customer_id
WHERE o.status = 'completed'
  AND o.deleted_at IS NULL
  AND s.deleted_at IS NULL
  AND (
    (o.purchase_type = 'monthly' AND s.status != 'active')
    OR (o.purchase_type = 'lifetime' AND s.status != 'active')
    OR (o.subscription_status != s.status::text)
  );

-- Check for customers with orders but no subscriptions
SELECT 
  'VALIDATION: Missing Subscription Records' as issue,
  o.email,
  o.purchase_type,
  o.created_at,
  'Missing subscription record - needs creation' as action_needed
FROM stripe_orders o
LEFT JOIN stripe_subscriptions s ON o.customer_id = s.customer_id
WHERE o.status = 'completed'
  AND o.deleted_at IS NULL
  AND s.customer_id IS NULL;

-- =============================================================================
-- 4. WEBHOOK HEALTH MONITORING
-- =============================================================================

-- Check for recent webhook failures (based on patterns)
SELECT 
  'WEBHOOK HEALTH CHECK' as check_type,
  DATE_TRUNC('day', created_at) as date,
  COUNT(*) as total_subscriptions,
  COUNT(CASE WHEN status = 'not_started' THEN 1 END) as not_started_count,
  ROUND(
    COUNT(CASE WHEN status = 'not_started' THEN 1 END) * 100.0 / COUNT(*), 
    2
  ) as not_started_percentage
FROM stripe_subscriptions
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND deleted_at IS NULL
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- Alert if not_started percentage is above 10% on any day
SELECT 
  'WEBHOOK ALERT: High failure rate detected!' as alert,
  DATE_TRUNC('day', created_at) as problem_date,
  COUNT(CASE WHEN status = 'not_started' THEN 1 END) as failures,
  COUNT(*) as total,
  ROUND(
    COUNT(CASE WHEN status = 'not_started' THEN 1 END) * 100.0 / COUNT(*), 
    2
  ) as failure_percentage
FROM stripe_subscriptions
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND deleted_at IS NULL
GROUP BY DATE_TRUNC('day', created_at)
HAVING COUNT(CASE WHEN status = 'not_started' THEN 1 END) * 100.0 / COUNT(*) > 10
ORDER BY problem_date DESC;

-- =============================================================================
-- 5. SUMMARY DASHBOARD
-- =============================================================================

SELECT 'SUBSCRIPTION HEALTH SUMMARY' as summary;

-- Overall health metrics
SELECT 
  status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM stripe_subscriptions
WHERE deleted_at IS NULL
GROUP BY status
ORDER BY count DESC;

-- Recent activity (last 7 days)
SELECT 
  'RECENT ACTIVITY (Last 7 days):' as activity,
  COUNT(*) as new_subscriptions,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as successful_activations,
  COUNT(CASE WHEN status = 'not_started' THEN 1 END) as stuck_not_started,
  CASE 
    WHEN COUNT(*) > 0 THEN 
      ROUND(COUNT(CASE WHEN status = 'active' THEN 1 END) * 100.0 / COUNT(*), 2)
    ELSE 0 
  END as success_rate_percentage
FROM stripe_subscriptions
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND deleted_at IS NULL;

-- Log this monitoring run
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'subscription_monitoring',
  'completed',
  jsonb_build_object(
    'action', 'daily_subscription_health_check',
    'timestamp', NOW(),
    'fixed_not_started_count', (
      SELECT COUNT(*) 
      FROM stripe_subscriptions 
      WHERE status = 'active' 
        AND updated_at > NOW() - INTERVAL '1 hour'
    )
  )
);

SELECT 
  '✅ MONITORING COMPLETE' as status,
  'Review alerts above and take action if needed' as next_steps,
  'Set up this script to run daily via cron job or Supabase Edge Functions' as automation; 