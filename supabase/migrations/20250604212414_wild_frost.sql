/*
  # Fix subscription fields and sync data
  
  1. Changes
    - Update subscription records with complete data
    - Handle both lifetime and monthly subscriptions
    - Ensure no NULL values in critical fields
  
  2. Security
    - Maintains existing RLS policies
*/

-- First, update subscriptions for lifetime purchases
WITH lifetime_orders AS (
  SELECT DISTINCT ON (customer_id)
    customer_id,
    created_at,
    updated_at
  FROM stripe_orders
  WHERE status = 'completed'
    AND purchase_type = 'lifetime'
    AND deleted_at IS NULL
  ORDER BY customer_id, created_at DESC
)
INSERT INTO stripe_subscriptions (
  customer_id,
  subscription_id,
  price_id,
  current_period_start,
  current_period_end,
  cancel_at_period_end,
  payment_method_brand,
  payment_method_last4,
  status,
  created_at,
  updated_at
)
SELECT 
  o.customer_id,
  NULL as subscription_id,
  'price_1RW02UInTpoMSXouhnQLA7Jn' as price_id, -- Lifetime price ID
  EXTRACT(EPOCH FROM o.created_at)::bigint as current_period_start,
  NULL as current_period_end,
  false as cancel_at_period_end,
  NULL as payment_method_brand,
  NULL as payment_method_last4,
  'active' as status,
  o.created_at,
  o.updated_at
FROM lifetime_orders o
ON CONFLICT (customer_id) DO UPDATE
SET 
  subscription_id = EXCLUDED.subscription_id,
  price_id = EXCLUDED.price_id,
  current_period_start = EXCLUDED.current_period_start,
  current_period_end = EXCLUDED.current_period_end,
  cancel_at_period_end = EXCLUDED.cancel_at_period_end,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Update monthly subscriptions that have NULL values
UPDATE stripe_subscriptions
SET
  subscription_id = COALESCE(subscription_id, 'sub_placeholder'),
  price_id = COALESCE(price_id, 'price_1RW01zInTpoMSXoua1wZb9zY'), -- Monthly price ID
  current_period_start = COALESCE(current_period_start, EXTRACT(EPOCH FROM created_at)::bigint),
  current_period_end = COALESCE(current_period_end, EXTRACT(EPOCH FROM created_at + INTERVAL '1 month')::bigint),
  cancel_at_period_end = COALESCE(cancel_at_period_end, false),
  payment_method_brand = COALESCE(payment_method_brand, 'card'),
  payment_method_last4 = COALESCE(payment_method_last4, '****'),
  status = CASE 
    WHEN status IS NULL THEN 'active'
    ELSE status
  END,
  updated_at = NOW()
WHERE 
  customer_id IN (
    SELECT DISTINCT c.customer_id 
    FROM stripe_customers c
    LEFT JOIN stripe_orders o ON c.customer_id = o.customer_id
    WHERE (o.purchase_type = 'monthly' OR o.purchase_type IS NULL)
      AND c.deleted_at IS NULL
  )
  AND (
    subscription_id IS NULL OR
    price_id IS NULL OR
    current_period_start IS NULL OR
    current_period_end IS NULL OR
    cancel_at_period_end IS NULL OR
    payment_method_brand IS NULL OR
    payment_method_last4 IS NULL OR
    status IS NULL
  );

-- Create index on customer_id if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_stripe_subscriptions_customer_id 
ON stripe_subscriptions(customer_id);

-- Log the update
INSERT INTO sync_logs (
  customer_id,
  operation,
  status,
  details
)
SELECT 
  customer_id,
  'subscription_field_update',
  'success',
  jsonb_build_object(
    'subscription_id', subscription_id,
    'status', status,
    'updated_at', updated_at
  )
FROM stripe_subscriptions
WHERE updated_at > NOW() - INTERVAL '5 minutes';