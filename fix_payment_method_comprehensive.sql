/*
  # Comprehensive Payment Method Last4 Fix
  
  ## ROOT CAUSE ANALYSIS:
  
  ### Why you're not getting correct payment_method_last4 card digits:
  
  1. **MIGRATION BUGS**: Previous migrations like bronze_bar.sql used:
     ```sql
     SUBSTRING(o.payment_intent_id FROM '.{4}$')
     ```
     This takes the last 4 characters from payment_intent_id like "pi_3QRD..." 
     which gives you "..." instead of actual card digits!
  
  2. **MD5 HASH FAKE DATA**: Some migrations generated fake data using MD5 hashes:
     ```sql
     SUBSTRING(MD5(o.payment_intent_id) FROM 1 FOR 4)
     ```
     This creates fake characters like 'cac6', '37d8' that look nothing like card digits.
  
  3. **WEBHOOK SUCCESS BUT EXISTING BAD DATA**: Your webhook handlers are mostly correct
     and DO capture real card data properly from Stripe, but they only run for NEW orders.
     Existing bad data from previous migrations was never fixed.
  
  4. **FALLBACK TO DEFAULTS**: When webhooks can't get payment method data, they fall back
     to '****' which is correct, but the old bad data was never cleaned up.
  
  ## THE FIX:
*/

-- Step 1: Analyze the current situation
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

-- Step 2: Show examples of the bad data
SELECT 
  'EXAMPLES OF BAD PAYMENT METHOD DATA' as examples;

SELECT 
  sc.email,
  so.payment_intent_id,
  so.payment_method_last4,
  so.payment_method_brand,
  CASE 
    WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 'GOOD: Real card digits'
    WHEN so.payment_method_last4 = '****' THEN 'OK: Default placeholder'
    WHEN so.payment_method_last4 ~ '^[a-f0-9]{4}$' AND so.payment_method_last4 !~ '^[0-9]{4}$' THEN 'BAD: MD5 hash fake data'
    WHEN LENGTH(so.payment_intent_id) >= 4 AND RIGHT(so.payment_intent_id, 4) = so.payment_method_last4 THEN 'BAD: Last 4 chars of payment_intent_id'
    ELSE 'BAD: Other fake data'
  END as data_status,
  so.created_at
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND so.payment_method_last4 !~ '^[0-9]{4}$'
  AND so.payment_method_last4 != '****'
ORDER BY so.created_at DESC
LIMIT 15;

-- Step 3: Clean up ALL fake payment method data
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
    -- And not already the clean default
    AND payment_method_last4 != '****'
  );

-- Step 4: Also clean stripe_subscriptions table
UPDATE stripe_subscriptions
SET 
  payment_method_last4 = '****',
  payment_method_brand = 'card',
  updated_at = NOW()
WHERE deleted_at IS NULL
  AND (
    payment_method_last4 !~ '^[0-9]{4}$' 
    AND payment_method_last4 != '****'
  );

-- Step 5: Show cleanup results
SELECT 
  'CLEANUP RESULTS' as status,
  COUNT(*) as total_orders,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as cleaned_to_placeholder,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_data_preserved,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as remaining_bad_data
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL;

-- Step 6: Create monitoring view for data quality
CREATE OR REPLACE VIEW payment_method_quality_monitor AS
SELECT 
  'Real-time Quality Monitor' as monitor_type,
  COUNT(*) as total_active_orders,
  COUNT(CASE WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as real_card_data,
  COUNT(CASE WHEN so.payment_method_last4 = '****' THEN 1 END) as pending_sync,
  COUNT(CASE WHEN so.payment_method_last4 !~ '^[0-9]{4}$' AND so.payment_method_last4 != '****' THEN 1 END) as bad_data,
  ROUND((COUNT(CASE WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2) as quality_percentage,
  COUNT(CASE WHEN so.created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as recent_orders,
  COUNT(CASE WHEN so.created_at > NOW() - INTERVAL '24 hours' AND so.payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as recent_with_real_data
FROM stripe_orders so
WHERE so.status = 'completed' AND so.deleted_at IS NULL;

-- Step 7: Identify users that need payment method sync from Stripe
CREATE OR REPLACE VIEW users_needing_stripe_sync AS
SELECT 
  sc.customer_id,
  sc.email,
  sc.user_id,
  so.payment_intent_id,
  so.purchase_type,
  so.payment_method_last4,
  'Needs real payment method data from Stripe' as action_needed,
  so.created_at as order_date
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND so.payment_method_last4 = '****'  -- Only clean placeholders, not bad data
ORDER BY so.created_at DESC;

-- Step 8: Log the comprehensive fix
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'comprehensive_payment_method_fix',
  'completed',
  jsonb_build_object(
    'action', 'cleaned_all_fake_payment_method_data_and_analyzed_root_causes',
    'timestamp', NOW(),
    'root_causes', ARRAY[
      'Previous migrations used SUBSTRING(payment_intent_id FROM ''.{4}$'') giving fake digits',
      'MD5 hash generation created fake data like ''cac6'', ''37d8''',
      'Webhook handlers work correctly but only for new orders',
      'Existing bad data was never cleaned up'
    ],
         'fix_actions', ARRAY[
       'Reset all fake data to clean *** placeholder',
       'Preserved any real 4-digit card data',
       'Created monitoring views for data quality',
       'Identified users needing Stripe sync'
     ],
    'next_steps', ARRAY[
      'Run Stripe sync for users with *** placeholder',
      'Monitor new orders to ensure webhooks capture real card data',
      'Use quality monitor view to track improvement'
    ]
  )
);

-- Step 9: Show final quality report
SELECT * FROM payment_method_quality_monitor;

-- Step 10: Show sample of users needing sync (limited output)
SELECT 
  'USERS NEEDING STRIPE PAYMENT METHOD SYNC (Sample)' as info;

SELECT 
  email,
  purchase_type,
  payment_method_last4,
  action_needed,
  order_date
FROM users_needing_stripe_sync 
LIMIT 10;

-- Step 11: Show total counts
SELECT 
  'SUMMARY COUNTS' as summary,
  (SELECT COUNT(*) FROM users_needing_stripe_sync WHERE purchase_type = 'monthly') as monthly_users_needing_sync,
  (SELECT COUNT(*) FROM users_needing_stripe_sync WHERE purchase_type = 'lifetime') as lifetime_users_needing_sync,
  (SELECT COUNT(*) FROM users_needing_stripe_sync) as total_users_needing_sync; 