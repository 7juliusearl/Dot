/*
  # Add payment method columns to stripe_orders
  
  1. Changes
    - Add payment_method_brand column to stripe_orders
    - Add payment_method_last4 column to stripe_orders
    - Update existing records to get payment info from Stripe webhooks
  
  2. Benefits
    - Allows removing stripe_subscriptions table dependency
    - Shows actual card details instead of payment_intent_id characters
    - Single source of truth for all payment data
*/

-- Add payment method columns to stripe_orders
ALTER TABLE stripe_orders
  ADD COLUMN IF NOT EXISTS payment_method_brand text,
  ADD COLUMN IF NOT EXISTS payment_method_last4 text;

-- Add index for payment method queries
CREATE INDEX IF NOT EXISTS idx_stripe_orders_payment_method 
ON stripe_orders(customer_id, payment_method_brand) 
WHERE deleted_at IS NULL;

-- Update existing orders with payment method data from stripe_subscriptions (if available)
UPDATE stripe_orders o
SET 
  payment_method_brand = s.payment_method_brand,
  payment_method_last4 = s.payment_method_last4,
  updated_at = NOW()
FROM stripe_subscriptions s
WHERE o.customer_id = s.customer_id
  AND o.status = 'completed'
  AND o.deleted_at IS NULL
  AND s.deleted_at IS NULL
  AND (o.payment_method_brand IS NULL OR o.payment_method_last4 IS NULL)
  AND s.payment_method_brand IS NOT NULL
  AND s.payment_method_last4 IS NOT NULL;

-- Set default values for orders without payment method data
UPDATE stripe_orders
SET 
  payment_method_brand = COALESCE(payment_method_brand, 'card'),
  payment_method_last4 = COALESCE(payment_method_last4, '****'),
  updated_at = NOW()
WHERE status = 'completed'
  AND deleted_at IS NULL
  AND (payment_method_brand IS NULL OR payment_method_last4 IS NULL);

-- Log the migration
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'add_payment_method_columns',
  'completed',
  jsonb_build_object(
    'action', 'added_payment_method_brand_and_last4_to_stripe_orders',
    'timestamp', NOW(),
    'updated_records', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE updated_at > NOW() - INTERVAL '5 minutes'
      AND payment_method_brand IS NOT NULL
    )
  )
); 