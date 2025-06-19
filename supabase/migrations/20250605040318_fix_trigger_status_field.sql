-- Fix the sync_stripe_subscription function to remove references to non-existent 'status' field in stripe_customers table
-- The function was trying to access NEW.status when triggered from stripe_customers, but that table has no status field

CREATE OR REPLACE FUNCTION "public"."sync_stripe_subscription"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

  -- Handle lifetime purchases (only for stripe_orders table which has status field)
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
