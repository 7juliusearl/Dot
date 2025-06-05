/*
  # Add subscription sync logging and automation
  
  1. Changes
    - Add sync_logs table for tracking sync operations
    - Add indexes for better performance
    - Create trigger function for subscription syncing
    - Set up triggers for customers and orders
  
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

-- Create function to handle subscription updates
CREATE OR REPLACE FUNCTION public.sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
  v_customer_id text;
BEGIN
  -- Determine customer_id and status based on the triggering table
  IF TG_TABLE_NAME = 'stripe_orders' THEN
    v_customer_id := NEW.customer_id;
    v_status := NEW.status::text;
  ELSE -- stripe_customers
    v_customer_id := NEW.customer_id;
    v_status := 'new_customer';
  END IF;

  -- Log sync attempt
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (v_customer_id, 'sync_start', 'pending', jsonb_build_object('trigger_source', TG_TABLE_NAME));

  -- Update subscription status based on order type
  IF TG_TABLE_NAME = 'stripe_orders' AND v_status = 'completed' THEN
    IF NEW.purchase_type = 'lifetime' THEN
      -- For lifetime purchases, create/update subscription record
      INSERT INTO stripe_subscriptions (
        customer_id,
        status,
        cancel_at_period_end
      ) VALUES (
        v_customer_id,
        'active',
        false
      )
      ON CONFLICT (customer_id) DO UPDATE
      SET status = 'active',
          cancel_at_period_end = false,
          updated_at = NOW();
    END IF;
  END IF;

  -- Log completion
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    v_customer_id,
    'sync_complete',
    'success',
    jsonb_build_object(
      'trigger_source', TG_TABLE_NAME,
      'action', TG_OP
    )
  );

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

-- Update existing customers to trigger sync
UPDATE stripe_customers 
SET updated_at = NOW() 
WHERE deleted_at IS NULL;