/*
  # Update Stripe Customer Email
  
  1. Changes
    - Update existing stripe_customers records with email from auth.users
    - Add trigger to automatically set email when creating new stripe_customers
  
  2. Security
    - Maintains existing RLS policies
*/

-- Update existing records with email from auth.users
UPDATE stripe_customers
SET email = u.email
FROM auth.users u
WHERE stripe_customers.user_id = u.id
AND stripe_customers.email IS NULL;

-- Create function to set email on new records
CREATE OR REPLACE FUNCTION set_stripe_customer_email()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email = (
    SELECT email 
    FROM auth.users 
    WHERE id = NEW.user_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically set email
DROP TRIGGER IF EXISTS set_stripe_customer_email_trigger ON stripe_customers;
CREATE TRIGGER set_stripe_customer_email_trigger
  BEFORE INSERT ON stripe_customers
  FOR EACH ROW
  EXECUTE FUNCTION set_stripe_customer_email();