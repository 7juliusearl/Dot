/*
  # Add purchase type to orders
  
  1. Changes
    - Add purchase_type column to stripe_orders table
    - Update stripe_user_orders view to include purchase type
  
  2. Security
    - Maintains existing security settings
*/

-- Add purchase_type column to stripe_orders
ALTER TABLE stripe_orders
  ADD COLUMN purchase_type text CHECK (purchase_type IN ('lifetime', 'monthly'));

-- Drop and recreate the view to include purchase_type
DROP VIEW IF EXISTS stripe_user_orders;
CREATE VIEW stripe_user_orders WITH (security_invoker = true) AS
SELECT
    c.customer_id,
    o.id as order_id,
    o.checkout_session_id,
    o.payment_intent_id,
    o.amount_subtotal,
    o.amount_total,
    o.currency,
    o.payment_status,
    o.status as order_status,
    o.created_at as order_date,
    o.purchase_type
FROM stripe_customers c
LEFT JOIN stripe_orders o ON c.customer_id = o.customer_id
WHERE c.user_id = auth.uid()
AND c.deleted_at IS NULL
AND o.deleted_at IS NULL;