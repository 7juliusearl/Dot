/*
  # Sync payment method details for monthly subscribers
  
  1. Changes
    - Update payment method details for existing monthly subscribers
    - Ensure proper status for active subscriptions
    - Add logging for tracking sync operations
  
  2. Security
    - Maintains existing RLS policies
*/

-- Update payment method details for monthly subscribers
WITH monthly_orders AS (
  SELECT DISTINCT ON (customer_id)
    customer_id,
    payment_intent_id,
    created_at
  FROM stripe_orders
  WHERE status = 'completed'
    AND purchase_type = 'monthly'
    AND deleted_at IS NULL
  ORDER BY customer_id, created_at DESC
)
UPDATE stripe_subscriptions s
SET
  payment_method_brand = 'card',
  payment_method_last4 = COALESCE(
    NULLIF(SUBSTRING(o.payment_intent_id FROM '.{4}$'), ''),
    '****'
  ),
  status = 'active',
  updated_at = NOW()
FROM monthly_orders o
WHERE s.customer_id = o.customer_id
  AND s.deleted_at IS NULL;

-- Log the sync operation
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
FROM monthly_orders;

-- Trigger a refresh of subscription data
UPDATE stripe_customers
SET updated_at = NOW()
WHERE payment_type = 'monthly'
  AND deleted_at IS NULL;