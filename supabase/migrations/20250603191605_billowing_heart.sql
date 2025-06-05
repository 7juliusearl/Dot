/*
  # Add email column to stripe_customers table

  1. Changes
    - Add email column to stripe_customers table
    - Update existing records with email from auth.users
  
  2. Security
    - No changes to RLS policies needed
*/

-- Add email column if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'stripe_customers' AND column_name = 'email'
  ) THEN
    ALTER TABLE stripe_customers ADD COLUMN email text;
  END IF;
END $$;

-- Update existing records with email from auth.users
UPDATE stripe_customers
SET email = auth.users.email
FROM auth.users
WHERE stripe_customers.user_id = auth.users.id
AND stripe_customers.email IS NULL;