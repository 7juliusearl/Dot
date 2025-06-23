-- EMERGENCY CHECK: Payment Method Data Quality Issue Analysis
-- Run this to see what's wrong with the payment method data again

-- Step 1: Current data quality overview
SELECT 
  'CURRENT PAYMENT METHOD DATA ANALYSIS' as analysis,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_digits,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as default_placeholder,
  COUNT(CASE WHEN payment_method_last4 ~ '^[a-f0-9]{4}$' AND payment_method_last4 !~ '^[0-9]{4}$' THEN 1 END) as md5_fake_data,
  COUNT(CASE WHEN payment_method_last4 ~ '[^0-9*]' THEN 1 END) as other_fake_data,
  ROUND((COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2) as real_data_percentage
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

-- Step 2: Show recent orders to see if the issue is affecting new data
SELECT 
  'RECENT ORDERS (Last 10)' as recent_check,
  sc.email,
  so.payment_intent_id,
  so.payment_method_last4,
  so.payment_method_brand,
  so.purchase_type,
  CASE 
    WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN '✅ GOOD: Real card digits'
    WHEN so.payment_method_last4 = '****' THEN '⚠️ OK: Default placeholder'
    WHEN so.payment_method_last4 ~ '^[a-f0-9]{4}$' AND so.payment_method_last4 !~ '^[0-9]{4}$' THEN '❌ BAD: MD5 hash fake data'
    WHEN LENGTH(so.payment_intent_id) >= 4 AND RIGHT(so.payment_intent_id, 4) = so.payment_method_last4 THEN '❌ BAD: Last 4 chars of payment_intent_id'
    ELSE '❌ BAD: Other fake data'
  END as data_status,
  so.created_at
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 10;

-- Step 3: Show all current bad data examples
SELECT 
  'ALL BAD PAYMENT METHOD DATA' as bad_data_examples,
  sc.email,
  so.payment_intent_id,
  so.payment_method_last4,
  so.payment_method_brand,
  so.purchase_type,
  CASE 
    WHEN so.payment_method_last4 ~ '^[a-f0-9]{4}$' AND so.payment_method_last4 !~ '^[0-9]{4}$' THEN 'MD5 hash fake data'
    WHEN LENGTH(so.payment_intent_id) >= 4 AND RIGHT(so.payment_intent_id, 4) = so.payment_method_last4 THEN 'Last 4 chars of payment_intent_id'
    ELSE 'Other fake data'
  END as problem_type,
  so.created_at
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND so.payment_method_last4 !~ '^[0-9]{4}$'
  AND so.payment_method_last4 != '****'
ORDER BY so.created_at DESC;

-- Step 4: Check subscription data quality
SELECT 
  'SUBSCRIPTION DATA QUALITY' as subscription_check,
  COUNT(*) as total_subscriptions,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_digits,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as default_placeholder,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as fake_data,
  COUNT(CASE WHEN subscription_status IS NULL THEN 1 END) as null_status,
  COUNT(CASE WHEN subscription_id IS NULL AND created_at > NOW() - INTERVAL '7 days' THEN 1 END) as recent_null_subscription_id
FROM stripe_subscriptions 
WHERE deleted_at IS NULL;

-- Step 5: Check recent webhook logs to see if they're working
SELECT 
  'RECENT SYNC LOGS' as log_check,
  operation,
  status,
  details,
  created_at
FROM sync_logs 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 10;

-- Step 6: Check what might be causing the resurface
SELECT 
  'ORDERS BY DATE - IDENTIFY PATTERN' as date_pattern,
  DATE(created_at) as order_date,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as good_data,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as placeholder,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as bad_data,
  ROUND((COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) * 100.0 / COUNT(*)), 2) as bad_percentage
FROM stripe_orders 
WHERE status = 'completed' 
  AND deleted_at IS NULL
  AND created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY order_date DESC; 