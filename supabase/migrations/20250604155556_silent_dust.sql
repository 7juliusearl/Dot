/*
  # Fix Stripe Customers Table Constraints

  1. Changes
    - Make customer_id nullable to allow for initial user creation
    - Add default values for beta_user and payment_type
    - Modify foreign key constraint to handle user deletion gracefully
  
  2. Security
    - Maintain existing RLS policies
    - Ensure data integrity while allowing for initial user creation
*/

-- Make customer_id nullable and add default values
ALTER TABLE stripe_customers 
  ALTER COLUMN customer_id DROP NOT NULL,
  ALTER COLUMN beta_user SET DEFAULT true,
  ALTER COLUMN payment_type SET DEFAULT 'monthly';

-- Add ON DELETE CASCADE to user_id foreign key
ALTER TABLE stripe_customers 
  DROP CONSTRAINT IF EXISTS stripe_customers_user_id_fkey,
  ADD CONSTRAINT stripe_customers_user_id_fkey 
    FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE;

-- Ensure RLS is enabled
ALTER TABLE stripe_customers ENABLE ROW LEVEL SECURITY;