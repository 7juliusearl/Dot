-- ANALYSIS: Why do we have more stripe_subscriptions entries than active Stripe subscriptions?
-- And why are there tons of NULL values?

SELECT 'SUBSCRIPTION DISCREPANCY ANALYSIS' as analysis_title;

-- 1. Current active subscriptions from CSV vs Database
SELECT 
  'ACTIVE STRIPE SUBSCRIPTIONS FROM CSV: ~19 monthly subscribers' as csv_count,
  'Expected: memo.gsalinas@gmail.com, madicpics@gmail.com, davidkeyns@gmail.com, etc.' as example_users;

-- 2. Count total entries in stripe_subscriptions table
SELECT 
  'TOTAL STRIPE_SUBSCRIPTIONS TABLE ENTRIES:' as info,
  COUNT(*) as total_entries,
  COUNT(CASE WHEN subscription_id IS NOT NULL THEN 1 END) as has_subscription_id,
  COUNT(CASE WHEN subscription_id IS NULL THEN 1 END) as null_subscription_id,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as active_status,
  COUNT(CASE WHEN deleted_at IS NULL THEN 1 END) as not_deleted
FROM stripe_subscriptions;

-- 3. Break down by subscription status and NULL fields
SELECT 
  'STRIPE_SUBSCRIPTIONS BREAKDOWN BY STATUS:' as info,
  status,
  COUNT(*) as count,
  COUNT(CASE WHEN subscription_id IS NULL THEN 1 END) as null_subscription_id,
  COUNT(CASE WHEN price_id IS NULL THEN 1 END) as null_price_id,
  COUNT(CASE WHEN current_period_start IS NULL THEN 1 END) as null_period_start,
  COUNT(CASE WHEN current_period_end IS NULL THEN 1 END) as null_period_end,
  COUNT(CASE WHEN payment_method_brand IS NULL THEN 1 END) as null_payment_brand,
  COUNT(CASE WHEN payment_method_last4 IS NULL THEN 1 END) as null_payment_last4
FROM stripe_subscriptions 
WHERE deleted_at IS NULL
GROUP BY status
ORDER BY count DESC;

-- 4. Check what customer types are in stripe_subscriptions
SELECT 
  'CUSTOMER TYPES IN STRIPE_SUBSCRIPTIONS:' as info,
  c.payment_type,
  COUNT(s.*) as subscription_entries,
  COUNT(CASE WHEN s.subscription_id IS NOT NULL THEN 1 END) as has_subscription_id,
  COUNT(CASE WHEN s.status = 'active' THEN 1 END) as active_subscriptions
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.deleted_at IS NULL AND c.deleted_at IS NULL
GROUP BY c.payment_type;

-- 5. Find entries that shouldn't be there (lifetime users in subscriptions)
SELECT 
  'LIFETIME USERS INCORRECTLY IN STRIPE_SUBSCRIPTIONS:' as issue,
  COUNT(*) as incorrect_lifetime_entries
FROM stripe_subscriptions s
JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE c.payment_type = 'lifetime' 
  AND s.deleted_at IS NULL 
  AND c.deleted_at IS NULL;

-- 6. Check for users with multiple subscription entries (duplicates)
SELECT 
  'DUPLICATE SUBSCRIPTION ENTRIES:' as issue,
  customer_id,
  COUNT(*) as duplicate_count
FROM stripe_subscriptions 
WHERE deleted_at IS NULL
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 7. Users in stripe_subscriptions but missing from CSV (canceled/failed subscriptions)
SELECT 
  'SUBSCRIPTIONS NOT IN ACTIVE CSV (LIKELY CANCELED/FAILED):' as info,
  s.customer_id,
  c.email,
  s.status,
  s.subscription_id,
  s.cancel_at_period_end,
  s.created_at,
  s.updated_at
FROM stripe_subscriptions s
LEFT JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE s.deleted_at IS NULL 
  AND c.deleted_at IS NULL
  AND c.email NOT IN (
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
  )
ORDER BY s.created_at DESC;

-- 8. Check the webhook processing history (why NULLs exist)
SELECT 
  'ROOT CAUSE ANALYSIS - WHY NULLS EXIST:' as analysis;

-- Historical data created before proper webhook setup
SELECT 
  'HISTORICAL DATA (Created before June 2025):' as reason,
  COUNT(*) as entries_count,
  MIN(created_at) as earliest_entry,
  MAX(created_at) as latest_entry
FROM stripe_subscriptions 
WHERE created_at < '2025-06-01'
  AND deleted_at IS NULL;

-- Recent entries with NULL fields (webhook failures)
SELECT 
  'RECENT ENTRIES WITH NULL FIELDS (Webhook Failures):' as reason,
  COUNT(*) as entries_with_nulls,
  COUNT(CASE WHEN subscription_id IS NULL THEN 1 END) as null_subscription_id,
  COUNT(CASE WHEN price_id IS NULL THEN 1 END) as null_price_id
FROM stripe_subscriptions 
WHERE created_at >= '2025-06-01'
  AND deleted_at IS NULL
  AND (subscription_id IS NULL OR price_id IS NULL OR current_period_start IS NULL);

-- 9. What should be cleaned up
SELECT 
  'CLEANUP RECOMMENDATIONS:' as recommendations;

-- Lifetime users that should be removed from stripe_subscriptions
SELECT 
  'REMOVE: Lifetime users from stripe_subscriptions' as action,
  COUNT(*) as entries_to_remove
FROM stripe_subscriptions s
JOIN stripe_customers c ON s.customer_id = c.customer_id
WHERE c.payment_type = 'lifetime' 
  AND s.deleted_at IS NULL;

-- Canceled/expired subscriptions that should be soft-deleted
SELECT 
  'SOFT DELETE: Canceled subscriptions' as action,
  COUNT(*) as entries_to_soft_delete
FROM stripe_subscriptions s
WHERE s.status IN ('canceled', 'unpaid', 'incomplete_expired')
  AND s.deleted_at IS NULL;

-- 10. Final summary
SELECT 
  'SUMMARY:' as summary,
  'Your CSV shows ~19 active monthly subscribers, but stripe_subscriptions table contains:' as explanation;

SELECT 
  status,
  COUNT(*) as count,
  CASE 
    WHEN status = 'active' THEN 'These should match your CSV (if all are monthly)'
    WHEN status = 'canceled' THEN 'These are canceled subscriptions - explain extra entries'
    WHEN status = 'incomplete' THEN 'These are failed/incomplete subscriptions'
    ELSE 'Other status entries'
  END as explanation
FROM stripe_subscriptions 
WHERE deleted_at IS NULL
GROUP BY status
ORDER BY count DESC; 