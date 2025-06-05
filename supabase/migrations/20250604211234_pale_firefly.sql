/*
  # Add subscription sync trigger
  
  1. Changes
    - Add trigger to sync subscription data on customer creation/update
    - Add trigger to sync subscription data on order completion
  
  2. Security
    - Functions run with security definer to ensure proper permissions
*/

-- Create or replace the sync trigger function
CREATE OR REPLACE FUNCTION public.sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the Edge Function to sync subscription data
  PERFORM
    net.http_post(
      url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/stripe-sync'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key'))
      ),
      body := jsonb_build_object(
        'customer_id', NEW.customer_id
      )
    );
  
  RETURN NEW;
END;
$$;

-- Create trigger for stripe_customers table
DROP TRIGGER IF EXISTS sync_subscription_on_customer_trigger ON stripe_customers;
CREATE TRIGGER sync_subscription_on_customer_trigger
  AFTER INSERT OR UPDATE ON stripe_customers
  FOR EACH ROW
  EXECUTE FUNCTION sync_stripe_subscription();

-- Create trigger for stripe_orders table
DROP TRIGGER IF EXISTS sync_subscription_on_order_trigger ON stripe_orders;
CREATE TRIGGER sync_subscription_on_order_trigger
  AFTER INSERT OR UPDATE OF status ON stripe_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION sync_stripe_subscription();