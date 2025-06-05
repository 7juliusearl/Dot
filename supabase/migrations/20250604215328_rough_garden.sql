/*
  # Clean up subscription data
  
  1. Changes
    - Remove lifetime access users from stripe_subscriptions table
    - Update stripe_user_subscriptions view to only show monthly subscribers
    - Add indexes for better performance
  
  2. Security
    - Maintains existing RLS policies
*/

-- First, create a backup of the subscriptions table
CREATE TABLE IF NOT EXISTS stripe_subscriptions_backup AS
SELECT * FROM stripe_subscriptions;

-- Remove lifetime access users from stripe_subscriptions
DELETE FROM stripe_subscriptions
WHERE customer_id IN (
  SELECT customer_id
  FROM stripe_orders
  WHERE status = 'completed'
    AND purchase_type = 'lifetime'
    AND deleted_at IS NULL
);

-- Update the view to only show monthly subscribers
DROP VIEW IF EXISTS stripe_user_subscriptions;
CREATE VIEW stripe_user_subscriptions WITH (security_invoker = true) AS
SELECT
    c.customer_id,
    s.subscription_id,
    s.status as subscription_status,
    s.price_id,
    s.current_period_start,
    s.current_period_end,
    s.cancel_at_period_end,
    s.payment_method_brand,
    s.payment_method_last4,
    c.beta_user,
    c.payment_type
FROM stripe_customers c
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
WHERE c.user_id = auth.uid()
  AND c.deleted_at IS NULL
  AND s.deleted_at IS NULL
  AND c.payment_type = 'monthly';

-- Add index for better performance if not exists
CREATE INDEX IF NOT EXISTS idx_stripe_subscriptions_payment_type 
ON stripe_customers(payment_type);

-- Log the cleanup
INSERT INTO sync_logs (
  customer_id,
  operation,
  status,
  details
)
SELECT 
  'system',
  'subscription_cleanup',
  'success',
  jsonb_build_object(
    'removed_count', (SELECT COUNT(*) FROM stripe_subscriptions_backup) - (SELECT COUNT(*) FROM stripe_subscriptions),
    'timestamp', NOW()
  );