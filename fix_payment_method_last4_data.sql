/*
  # Fix Payment Method Last4 Data Issues
  
  ## PROBLEM IDENTIFIED:
  1. Previous migrations generated FAKE card data by taking last 4 characters from payment_intent_id
  2. Payment intent IDs look like "pi_3Q..." which gives fake digits like "3Q.." instead of real card digits
  3. Some migrations used MD5 hashes creating completely fake data like 'cac6', '37d8'
  4. Webhook handlers have the correct logic but existing bad data wasn't fixed
  
  ## ROOT CAUSE:
  - Line 35 in bronze_bar.sql: SUBSTRING(o.payment_intent_id FROM '.{4}$')
  - This takes last 4 chars from payment_intent_id (like "pi_3Qxxxxxxxxx") = "xxxx" (not card digits!)
  - Should be getting actual card data from Stripe payment method API
  
  ## SOLUTION:
  1. Reset all fake payment method data
  2. Fix webhook handlers to properly capture real card data
  3. Create sync function to backfill real payment data from Stripe
*/

-- First, identify the scope of the problem
SELECT 
  'Payment Method Data Analysis' as analysis_type,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_digits,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as default_placeholders,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as fake_data
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

-- Show examples of fake data
SELECT 
  'Examples of FAKE card data (from payment_intent_id):' as info;

SELECT 
  sc.email,
  so.payment_intent_id,
  so.payment_method_last4,
  'FAKE - last 4 chars of payment_intent_id' as issue
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND so.payment_method_last4 !~ '^[0-9]{4}$'
  AND so.payment_method_last4 != '****'
ORDER BY so.created_at DESC
LIMIT 10;

-- Reset ALL fake payment method data to clean defaults
-- This includes data from payment_intent_id last 4 chars and MD5 hashes
UPDATE stripe_orders
SET 
  payment_method_last4 = '****',
  payment_method_brand = 'card',
  updated_at = NOW()
WHERE status = 'completed'
  AND deleted_at IS NULL
  AND (
    -- Not real 4-digit card numbers
    payment_method_last4 !~ '^[0-9]{4}$' 
    -- And not already the default
    AND payment_method_last4 != '****'
  );

-- Also fix stripe_subscriptions table
UPDATE stripe_subscriptions
SET 
  payment_method_last4 = '****',
  payment_method_brand = 'card',
  updated_at = NOW()
WHERE deleted_at IS NULL
  AND (
    -- Not real 4-digit card numbers
    payment_method_last4 !~ '^[0-9]{4}$' 
    -- And not already the default
    AND payment_method_last4 != '****'
  );

-- Show cleanup results
SELECT 
  'After cleanup:' as status,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as cleaned_to_default,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_digits_remaining
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

-- Log the cleanup operation
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'fix_payment_method_last4_fake_data',
  'completed',
  jsonb_build_object(
    'action', 'removed_all_fake_payment_method_last4_data',
    'timestamp', NOW(),
    'issue_description', 'Previous migrations incorrectly used payment_intent_id last 4 chars instead of real card digits',
    'orders_cleaned', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE payment_method_last4 = '****'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    ),
    'subscriptions_cleaned', (
      SELECT COUNT(*) 
      FROM stripe_subscriptions 
      WHERE payment_method_last4 = '****'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    ),
    'next_steps', ARRAY[
      'Run sync function to fetch real payment method data from Stripe',
      'Update webhook handlers to prevent future fake data',
      'Monitor for successful real card data population'
    ]
  )
);

-- Create a view to monitor payment method data quality
CREATE OR REPLACE VIEW payment_method_data_quality AS
SELECT 
  'Summary' as metric,
  COUNT(*) as total_active_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_data,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as pending_sync,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as still_fake_data,
  ROUND(
    (COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2
  ) as real_data_percentage
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL

UNION ALL

SELECT 
  'Monthly Subscriptions' as metric,
  COUNT(*) as total_active_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_data,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as pending_sync,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as still_fake_data,
  ROUND(
    (COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2
  ) as real_data_percentage
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL AND purchase_type = 'monthly'

UNION ALL

SELECT 
  'Lifetime Purchases' as metric,
  COUNT(*) as total_active_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_data,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as pending_sync,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as still_fake_data,
  ROUND(
    (COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2
  ) as real_data_percentage
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL AND purchase_type = 'lifetime';

-- Show the quality report
SELECT * FROM payment_method_data_quality; 