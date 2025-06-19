/*
  # Add subscription columns to stripe_orders for monthly users
  
  1. Changes
    - Add subscription_id for cancellations
    - Add current_period_start/end for billing cycles
    - Add cancel_at_period_end for cancellation status
    - Add subscription_status for subscription health
    - Add price_id for plan identification
  
  2. Benefits
    - Complete subscription management from stripe_orders
    - Monthly users can cancel subscriptions
    - Show proper billing dates and status
    - Single source of truth for all payment data
*/

-- Add subscription columns to stripe_orders (nullable for lifetime users)
ALTER TABLE stripe_orders
  ADD COLUMN IF NOT EXISTS subscription_id text,
  ADD COLUMN IF NOT EXISTS price_id text,
  ADD COLUMN IF NOT EXISTS current_period_start bigint,
  ADD COLUMN IF NOT EXISTS current_period_end bigint,
  ADD COLUMN IF NOT EXISTS cancel_at_period_end boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS subscription_status text;

-- Add index for subscription queries
CREATE INDEX IF NOT EXISTS idx_stripe_orders_subscription 
ON stripe_orders(customer_id, subscription_id) 
WHERE deleted_at IS NULL AND purchase_type = 'monthly';

-- Update existing monthly orders with subscription data from stripe_subscriptions
UPDATE stripe_orders o
SET 
  subscription_id = s.subscription_id,
  price_id = s.price_id,
  current_period_start = s.current_period_start,
  current_period_end = s.current_period_end,
  cancel_at_period_end = s.cancel_at_period_end,
  subscription_status = s.status::text,
  updated_at = NOW()
FROM stripe_subscriptions s
WHERE o.customer_id = s.customer_id
  AND o.purchase_type = 'monthly'
  AND o.status = 'completed'
  AND o.deleted_at IS NULL
  AND s.deleted_at IS NULL;

-- Set default values for monthly orders without subscription data
UPDATE stripe_orders
SET 
  subscription_status = COALESCE(subscription_status, 'active'),
  cancel_at_period_end = COALESCE(cancel_at_period_end, false),
  price_id = COALESCE(price_id, 'price_1RW01zInTpoMSXoua1wZb9zY'), -- Monthly price
  current_period_start = COALESCE(current_period_start, EXTRACT(EPOCH FROM created_at)::bigint),
  current_period_end = COALESCE(current_period_end, EXTRACT(EPOCH FROM created_at + INTERVAL '1 month')::bigint),
  updated_at = NOW()
WHERE purchase_type = 'monthly'
  AND status = 'completed'
  AND deleted_at IS NULL
  AND subscription_status IS NULL;

-- For lifetime users, ensure subscription columns remain NULL
UPDATE stripe_orders
SET 
  subscription_id = NULL,
  current_period_start = NULL,
  current_period_end = NULL,
  cancel_at_period_end = false,
  subscription_status = NULL,
  price_id = 'price_1RW02UInTpoMSXouhnQLA7Jn', -- Lifetime price
  updated_at = NOW()
WHERE purchase_type = 'lifetime'
  AND status = 'completed'
  AND deleted_at IS NULL;

-- Log the migration
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'add_subscription_columns_to_orders',
  'completed',
  jsonb_build_object(
    'action', 'added_subscription_columns_to_stripe_orders',
    'timestamp', NOW(),
    'monthly_orders_updated', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE purchase_type = 'monthly'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    ),
    'lifetime_orders_updated', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE purchase_type = 'lifetime'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    )
  )
); 