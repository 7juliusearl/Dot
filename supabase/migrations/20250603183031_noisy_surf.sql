/*
  # Add beta user tracking
  
  1. Changes
    - Add beta_user and payment_type columns to stripe_customers table
    - Update stripe_user_subscriptions view to include new columns
  
  2. Security
    - Maintains existing security settings
    - View remains security_invoker = true
*/

-- Add beta tracking columns to stripe_customers
ALTER TABLE stripe_customers 
ADD COLUMN IF NOT EXISTS beta_user boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS payment_type text CHECK (payment_type IN ('lifetime', 'monthly'));

-- Drop the existing view
DROP VIEW IF EXISTS stripe_user_subscriptions;

-- Recreate the view with the new columns
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
AND s.deleted_at IS NULL;