/*
  # Fix subscription sync system
  
  1. Changes
    - Create sync_logs table for tracking sync operations
    - Add indexes for better query performance
    - Create function to handle subscription updates locally
    - Add triggers for customer and order updates
  
  2. Security
    - Maintain existing RLS policies
    - Function runs with security definer
*/

-- Create logging table if it doesn't exist
CREATE TABLE IF NOT EXISTS sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id text NOT NULL,
  operation text NOT NULL,
  status text NOT NULL,
  error text,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stripe_subscriptions_customer_id ON stripe_subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_stripe_orders_customer_id ON stripe_orders(customer_id);

-- Create function to handle subscription updates
CREATE OR REPLACE FUNCTION public.sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_customer_id text;
  v_order_type text;
BEGIN
  -- Set customer_id based on the triggering table
  v_customer_id := CASE 
    WHEN TG_TABLE_NAME = 'stripe_orders' THEN NEW.customer_id
    ELSE NEW.customer_id
  END;

  -- Log sync start
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    v_customer_id,
    'sync_start',
    'pending',
    jsonb_build_object(
      'trigger_source', TG_TABLE_NAME,
      'trigger_op', TG_OP
    )
  );

  -- Handle lifetime purchases
  IF TG_TABLE_NAME = 'stripe_orders' AND NEW.status = 'completed' THEN
    v_order_type := NEW.purchase_type;
    
    IF v_order_type = 'lifetime' THEN
      -- Create or update subscription for lifetime purchase
      INSERT INTO stripe_subscriptions (
        id,
        customer_id,
        subscription_id,
        status,
        cancel_at_period_end,
        created_at,
        updated_at
      ) VALUES (
        DEFAULT,
        v_customer_id,
        NULL,
        'active',
        false,
        NOW(),
        NOW()
      )
      ON CONFLICT (customer_id) 
      DO UPDATE SET
        status = 'active',
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
      'trigger_op', TG_OP,
      'order_type', v_order_type
    )
  );

  RETURN NEW;
END;
$$;

-- Drop existing triggers
DROP TRIGGER IF EXISTS sync_subscription_on_customer_trigger ON stripe_customers;
DROP TRIGGER IF EXISTS sync_subscription_on_order_trigger ON stripe_orders;

-- Create new triggers
CREATE TRIGGER sync_subscription_on_customer_trigger
  AFTER INSERT OR UPDATE ON stripe_customers
  FOR EACH ROW
  EXECUTE FUNCTION sync_stripe_subscription();

CREATE TRIGGER sync_subscription_on_order_trigger
  AFTER INSERT OR UPDATE OF status ON stripe_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION sync_stripe_subscription();

-- Update existing completed lifetime orders to ensure subscriptions are created
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT DISTINCT customer_id 
    FROM stripe_orders 
    WHERE status = 'completed' 
    AND purchase_type = 'lifetime'
    AND deleted_at IS NULL
  LOOP
    INSERT INTO stripe_subscriptions (
      customer_id,
      status,
      cancel_at_period_end,
      created_at,
      updated_at
    ) VALUES (
      r.customer_id,
      'active',
      false,
      NOW(),
      NOW()
    )
    ON CONFLICT (customer_id) 
    DO UPDATE SET
      status = 'active',
      cancel_at_period_end = false,
      updated_at = NOW();
  END LOOP;
END;
$$;