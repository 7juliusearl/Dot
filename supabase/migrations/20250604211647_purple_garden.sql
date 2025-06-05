/*
  # Fix Stripe subscription sync
  
  1. Changes
    - Add logging table for sync operations
    - Add indexes for better performance
    - Update sync function with proper logging
    - Recreate triggers with updated function
  
  2. Security
    - Function runs with security definer
    - Maintains existing RLS policies
*/

-- Create logging table
CREATE TABLE IF NOT EXISTS sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id text NOT NULL,
  operation text NOT NULL,
  status text NOT NULL,
  error text,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Add index for customer_id on stripe_subscriptions
CREATE INDEX IF NOT EXISTS idx_stripe_subscriptions_customer_id ON stripe_subscriptions(customer_id);

-- Add index for customer_id on stripe_orders
CREATE INDEX IF NOT EXISTS idx_stripe_orders_customer_id ON stripe_orders(customer_id);

-- Update the sync function to include logging
CREATE OR REPLACE FUNCTION public.sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  response_status INT;
  response_body TEXT;
BEGIN
  -- Log sync attempt
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (NEW.customer_id, 'sync_start', 'pending', jsonb_build_object('trigger_source', TG_TABLE_NAME));

  -- Call the Edge Function to sync subscription data
  SELECT
    INTO response_status, response_body
    status, content::TEXT
  FROM
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

  -- Log sync result
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    NEW.customer_id,
    'sync_complete',
    CASE WHEN response_status = 200 THEN 'success' ELSE 'error' END,
    jsonb_build_object(
      'status_code', response_status,
      'response', response_body
    )
  );

  -- Raise notice for debugging
  RAISE NOTICE 'Sync completed for customer %. Status: %, Response: %', NEW.customer_id, response_status, response_body;

  RETURN NEW;
END;
$$;

-- Recreate triggers to ensure they're using the latest function version
DROP TRIGGER IF EXISTS sync_subscription_on_customer_trigger ON stripe_customers;
CREATE TRIGGER sync_subscription_on_customer_trigger
  AFTER INSERT OR UPDATE ON stripe_customers
  FOR EACH ROW
  EXECUTE FUNCTION sync_stripe_subscription();

DROP TRIGGER IF EXISTS sync_subscription_on_order_trigger ON stripe_orders;
CREATE TRIGGER sync_subscription_on_order_trigger
  AFTER INSERT OR UPDATE OF status ON stripe_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION sync_stripe_subscription();

-- Force a sync for all existing customers by updating them
UPDATE stripe_customers 
SET updated_at = NOW() 
WHERE deleted_at IS NULL;