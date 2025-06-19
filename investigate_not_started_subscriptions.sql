-- INVESTIGATE: The 16 "not_started" subscriptions
-- These explain why you have more entries than active Stripe subscriptions

SELECT 'INVESTIGATING NOT_STARTED SUBSCRIPTIONS' as investigation;

-- 1. Detailed look at not_started subscriptions
SELECT 
  'NOT_STARTED SUBSCRIPTION DETAILS:' as info,
  s.customer_id,
  c.email,
  s.subscription_id,
  s.price_id,
  s.current_period_start,
  s.current_period_end,
  s.payment_method_brand,
  s.payment_method_last4,
  s.cancel_at_period_end,
  s.created_at,
  s.updated_at,
  c.payment_type
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
ORDER BY s.created_at DESC;

-- 2. Check if these users have completed orders (they shouldn't be not_started if they paid)
SELECT 
  'NOT_STARTED BUT HAS COMPLETED ORDERS (Should be fixed):' as issue,
  s.customer_id,
  c.email,
  s.status as subscription_status,
  o.status as order_status,
  o.payment_status,
  o.purchase_type,
  s.created_at as subscription_created,
  o.created_at as order_created
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
LEFT JOIN stripe_orders o ON s.customer_id = o.customer_id
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
  AND o.status = 'completed'
  AND o.deleted_at IS NULL
ORDER BY s.created_at DESC;

-- 3. Check if not_started users exist in your active CSV
SELECT 
  'NOT_STARTED USERS FROM YOUR ACTIVE CSV (Should be active):' as critical_issue,
  s.customer_id,
  c.email,
  s.status,
  s.created_at
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND c.deleted_at IS NULL
  AND c.email IN (
    'memo.gsalinas@gmail.com',
    'madicpics@gmail.com', 
    'crawls.scant-2j@icloud.com',
    'davidkeyns@gmail.com',
    'candjphotography34@gmail.com',
    'mail@notyi.in',
    'bsmithphoto10@aol.com',
    'daviddeets@me.com',
    'leonardstephanie63@gmail.com',
    'ricardo@spixel.ch',
    'caitlinaphotographystl@gmail.com',
    'ali@mossandelder.com',
    'hcsphotog@gmail.com',
    'kristinelrivera16@gmail.com',
    'jspirit@me.com',
    'hello@fergiemedar.com',
    'paigc48@gmail.com',
    'kaitie@magnoliamaestudios.com',
    'erickson.media.videography@gmail.com'
  );

-- 4. Age analysis of not_started subscriptions
SELECT 
  'AGE ANALYSIS OF NOT_STARTED SUBSCRIPTIONS:' as analysis,
  CASE 
    WHEN created_at > NOW() - INTERVAL '1 day' THEN 'Last 24 hours'
    WHEN created_at > NOW() - INTERVAL '7 days' THEN 'Last week'
    WHEN created_at > NOW() - INTERVAL '30 days' THEN 'Last month'
    ELSE 'Older than 1 month'
  END as age_group,
  COUNT(*) as count
FROM stripe_subscriptions
WHERE status = 'not_started'
  AND deleted_at IS NULL
GROUP BY 
  CASE 
    WHEN created_at > NOW() - INTERVAL '1 day' THEN 'Last 24 hours'
    WHEN created_at > NOW() - INTERVAL '7 days' THEN 'Last week'
    WHEN created_at > NOW() - INTERVAL '30 days' THEN 'Last month'
    ELSE 'Older than 1 month'
  END
ORDER BY count DESC;

-- 5. Check NULL fields in not_started subscriptions
SELECT 
  'NULL FIELDS IN NOT_STARTED SUBSCRIPTIONS:' as analysis,
  COUNT(*) as total_not_started,
  COUNT(CASE WHEN subscription_id IS NULL THEN 1 END) as null_subscription_id,
  COUNT(CASE WHEN price_id IS NULL THEN 1 END) as null_price_id,
  COUNT(CASE WHEN current_period_start IS NULL THEN 1 END) as null_period_start,
  COUNT(CASE WHEN current_period_end IS NULL THEN 1 END) as null_period_end,
  COUNT(CASE WHEN payment_method_brand IS NULL THEN 1 END) as null_payment_brand
FROM stripe_subscriptions
WHERE status = 'not_started'
  AND deleted_at IS NULL;

-- 6. Recommended actions
SELECT 
  'RECOMMENDED ACTIONS:' as recommendations;

-- Users who should be activated (have completed orders)
SELECT 
  'ACTION 1: Activate these users (they have completed payments):' as action,
  COUNT(DISTINCT s.customer_id) as users_to_activate
FROM stripe_subscriptions s
JOIN stripe_orders o ON s.customer_id = o.customer_id
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND o.status = 'completed'
  AND o.deleted_at IS NULL;

-- Users who should be soft-deleted (no completed orders, old entries)
SELECT 
  'ACTION 2: Soft delete these users (no completed orders, old entries):' as action,
  COUNT(DISTINCT s.customer_id) as users_to_soft_delete
FROM stripe_subscriptions s
LEFT JOIN stripe_orders o ON s.customer_id = o.customer_id AND o.status = 'completed' AND o.deleted_at IS NULL
WHERE s.status = 'not_started'
  AND s.deleted_at IS NULL
  AND s.created_at < NOW() - INTERVAL '7 days'  -- Older than 7 days
  AND o.customer_id IS NULL;  -- No completed orders

SELECT 
  'SUMMARY: The 16 not_started subscriptions are likely incomplete checkouts or webhook failures' as summary,
  'Check if any of these emails appear in your active CSV - those should be activated immediately' as next_step; 