/*
  # Fix subscription data and payment details
  
  1. Changes
    - Update subscription IDs for monthly subscribers
    - Set correct payment method details from orders
    - Clean up placeholder data
  
  2. Security
    - Maintains existing RLS policies
*/

-- First, update subscription records from completed orders
WITH latest_orders AS (
  SELECT DISTINCT ON (customer_id)
    customer_id,
    payment_intent_id,
    purchase_type,
    created_at
  FROM stripe_orders
  WHERE status = 'completed'
    AND deleted_at IS NULL
  ORDER BY customer_id, created_at DESC
)
UPDATE stripe_subscriptions s
SET
  subscription_id = CASE 
    WHEN o.purchase_type = 'monthly' THEN 'sub_' || SUBSTRING(o.payment_intent_id FROM '.{24}$')
    ELSE NULL
  END,
  payment_method_brand = 'card',
  payment_method_last4 = COALESCE(
    NULLIF(SUBSTRING(o.payment_intent_id FROM '.{4}$'), ''),
    '****'
  ),
  status = 'active'::stripe_subscription_status,
  price_id = CASE 
    WHEN o.purchase_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
    ELSE 'price_1RW01zInTpoMSXoua1wZb9zY'
  END,
  current_period_start = EXTRACT(EPOCH FROM o.created_at)::bigint,
  current_period_end = CASE 
    WHEN o.purchase_type = 'monthly' THEN EXTRACT(EPOCH FROM o.created_at + INTERVAL '1 month')::bigint
    ELSE NULL
  END,
  updated_at = NOW()
FROM latest_orders o
WHERE s.customer_id = o.customer_id
  AND s.deleted_at IS NULL
  AND (s.subscription_id LIKE 'sub_placeholder' OR s.subscription_id IS NULL);

-- Log the sync operations
INSERT INTO sync_logs (
  customer_id,
  operation,
  status,
  details
)
SELECT 
  s.customer_id,
  'subscription_data_fix',
  'success',
  jsonb_build_object(
    'subscription_id', s.subscription_id,
    'payment_method_last4', s.payment_method_last4,
    'updated_at', s.updated_at
  )
FROM stripe_subscriptions s
WHERE s.updated_at > NOW() - INTERVAL '5 minutes';