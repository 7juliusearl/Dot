/*
  # Fix fake card data with real payment method information
  
  1. Problem
    - Users see fake card data like 'cac6', '37d8' instead of real last 4 digits
    - Previous migrations generated fake payment_method_last4 from MD5 hashes
    - Need to get real payment method data from Stripe subscriptions
  
  2. Solution
    - Reset all fake payment method data to defaults
    - Let the webhook/sync functions fetch real data from Stripe
    - For now, use clean defaults until real data is synced
*/

-- Show current state of payment method data
SELECT 
  'Current payment method data (showing fake data):' as info;

SELECT 
  sc.email,
  so.payment_method_last4,
  so.payment_method_brand,
  CASE 
    WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 'Real card digits'
    WHEN so.payment_method_last4 = '****' THEN 'Default fallback'
    ELSE 'FAKE DATA (from hash/ID)'
  END as data_type
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.purchase_type = 'monthly'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
ORDER BY so.created_at DESC;

-- Reset fake payment method data to clean defaults
-- We'll identify fake data as anything that's not 4 digits or ****
UPDATE stripe_orders
SET 
  payment_method_last4 = '****',
  payment_method_brand = 'card',
  updated_at = NOW()
WHERE status = 'completed'
  AND deleted_at IS NULL
  AND purchase_type = 'monthly'
  AND (
    -- Not 4 digits (fake data from hashes)
    payment_method_last4 !~ '^[0-9]{4}$' 
    -- And not already the default
    AND payment_method_last4 != '****'
  );

-- Show cleaned data
SELECT 
  'After cleanup - payment method data:' as info;

SELECT 
  sc.email,
  so.payment_method_last4,
  so.payment_method_brand,
  'Cleaned - ready for real data sync' as status
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.purchase_type = 'monthly'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND so.updated_at > NOW() - INTERVAL '5 minutes'
ORDER BY so.updated_at DESC;

-- Log the cleanup
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'cleanup_fake_payment_method_data',
  'completed',
  jsonb_build_object(
    'action', 'removed_fake_card_data_generated_from_hashes',
    'timestamp', NOW(),
    'records_cleaned', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE payment_method_last4 = '****'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    ),
    'next_step', 'sync_real_payment_method_data_from_stripe'
  )
); 