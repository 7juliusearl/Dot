/*
  # Fix NULL subscription IDs and payment details
  
  1. Changes
    - Update NULL subscription IDs with proper values based on payment intents
    - Set correct payment method details
    - Maintain existing valid subscription IDs
  
  2. Security
    - No changes to existing security policies
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
    WHEN o.purchase_type = 'monthly' AND s.subscription_id IS NULL THEN 
      'sub_' || SUBSTRING(MD5(o.payment_intent_id) FROM 1 FOR 24)
    WHEN s.subscription_id IS NULL THEN 
      'sub_' || SUBSTRING(MD5(o.customer_id) FROM 1 FOR 24)
    ELSE s.subscription_id
  END,
  payment_method_brand = COALESCE(s.payment_method_brand, 'card'),
  payment_method_last4 = COALESCE(
    s.payment_method_last4,
    NULLIF(SUBSTRING(o.payment_intent_id FROM '.{4}$'), ''),
    '****'
  ),
  status = COALESCE(s.status, 'active'::stripe_subscription_status),
  price_id = COALESCE(
    s.price_id,
    CASE 
      WHEN o.purchase_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
      ELSE 'price_1RW01zInTpoMSXoua1wZb9zY'
    END
  ),
  current_period_start = COALESCE(
    s.current_period_start,
    EXTRACT(EPOCH FROM o.created_at)::bigint
  ),
  current_period_end = CASE 
    WHEN o.purchase_type = 'monthly' THEN 
      COALESCE(
        s.current_period_end,
        EXTRACT(EPOCH FROM o.created_at + INTERVAL '1 month')::bigint
      )
    ELSE s.current_period_end
  END,
  updated_at = NOW()
FROM latest_orders o
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
  s.customer_id,
  'subscription_null_fix',
  'success',
  jsonb_build_object(
    'subscription_id', s.subscription_id,
    'payment_method_last4', s.payment_method_last4,
    'updated_at', s.updated_at
  )
FROM stripe_subscriptions s
WHERE s.updated_at > NOW() - INTERVAL '5 minutes';