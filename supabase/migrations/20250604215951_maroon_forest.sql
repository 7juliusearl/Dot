/*
  # Update subscription payment details
  
  1. Changes
    - Update payment method details for monthly subscribers
    - Add sync operation logs
    - Refresh customer data timestamps
  
  2. Security
    - No changes to existing security policies
*/

-- First, create a temporary table to store the latest orders
CREATE TEMPORARY TABLE temp_latest_orders AS
SELECT DISTINCT ON (customer_id)
  customer_id,
  payment_intent_id,
  created_at
FROM stripe_orders
WHERE status = 'completed'
  AND purchase_type = 'monthly'
  AND deleted_at IS NULL
ORDER BY customer_id, created_at DESC;

-- Update subscription payment details
UPDATE stripe_subscriptions s
SET
  payment_method_brand = 'card',
  payment_method_last4 = COALESCE(
    NULLIF(SUBSTRING(o.payment_intent_id FROM '.{4}$'), ''),
    '****'
  ),
  status = 'active'::stripe_subscription_status,
  updated_at = NOW()
FROM temp_latest_orders o
WHERE s.customer_id = o.customer_id
  AND s.deleted_at IS NULL;

-- Log the sync operations
INSERT INTO sync_logs (
  customer_id,
  operation,
  status,
  details
)
SELECT 
  customer_id,
  'payment_method_sync',
  'success',
  jsonb_build_object(
    'payment_intent_id', payment_intent_id,
    'timestamp', NOW()
  )
FROM temp_latest_orders;

-- Refresh customer data timestamps
UPDATE stripe_customers
SET updated_at = NOW()
WHERE payment_type = 'monthly'
  AND deleted_at IS NULL;

-- Clean up
DROP TABLE temp_latest_orders;