/*
  # Update Stripe Orders Table
  
  1. Changes
    - Make payment_intent_id nullable since some orders might not have it initially
    - Add email column to stripe_orders table
    - Add trigger to automatically set email from stripe_customers
  
  2. Security
    - Maintains existing RLS policies
*/

-- Make payment_intent_id nullable
ALTER TABLE stripe_orders
  ALTER COLUMN payment_intent_id DROP NOT NULL;

-- Add email column if it doesn't exist
ALTER TABLE stripe_orders
  ADD COLUMN IF NOT EXISTS email text;

-- Update existing orders with email from stripe_customers
UPDATE stripe_orders o
SET email = c.email
FROM stripe_customers c
WHERE o.customer_id = c.customer_id
AND o.email IS NULL;

-- Create function to set email on new orders
CREATE OR REPLACE FUNCTION set_stripe_order_email()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email = (
    SELECT email 
    FROM stripe_customers 
    WHERE customer_id = NEW.customer_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically set email
DROP TRIGGER IF EXISTS set_stripe_order_email_trigger ON stripe_orders;
CREATE TRIGGER set_stripe_order_email_trigger
  BEFORE INSERT ON stripe_orders
  FOR EACH ROW
  EXECUTE FUNCTION set_stripe_order_email();