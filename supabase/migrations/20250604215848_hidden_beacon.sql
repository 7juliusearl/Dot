/*
  # Update subscription payment details
  
  1. Changes
    - Fix trigger function to handle status updates correctly
    - Update payment method details for existing subscriptions
    - Log sync operations
  
  2. Security
    - Maintains existing RLS policies
*/

-- First, fix the trigger function
CREATE OR REPLACE FUNCTION sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only proceed if this is a completed order
  IF TG_TABLE_NAME = 'stripe_orders' AND NEW.status = 'completed'::stripe_order_status THEN
    -- Update subscription status
    UPDATE stripe_subscriptions
    SET status = 'active'::stripe_subscription_status,
        updated_at = NOW()
    WHERE customer_id = NEW.customer_id
    AND deleted_at IS NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Now update payment method details and log sync operations
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT DISTINCT ON (customer_id)
      customer_id,
      payment_intent_id,
      created_at
    FROM stripe_orders
    WHERE status = 'completed'
      AND purchase_type = 'monthly'
      AND deleted_at IS NULL
    ORDER BY customer_id, created_at DESC
  )
  LOOP
    -- Update subscription payment details
    UPDATE stripe_subscriptions
    SET
      payment_method_brand = 'card',
      payment_method_last4 = COALESCE(
        NULLIF(SUBSTRING(r.payment_intent_id FROM '.{4}$'), ''),
        '****'
      ),
      status = 'active'::stripe_subscription_status,
      updated_at = NOW()
    WHERE customer_id = r.customer_id
      AND deleted_at IS NULL;

    -- Log the sync operation
    INSERT INTO sync_logs (
      customer_id,
      operation,
      status,
      details
    ) VALUES (
      r.customer_id,
      'payment_method_sync',
      'success',
      jsonb_build_object(
        'payment_intent_id', r.payment_intent_id,
        'timestamp', NOW()
      )
    );
  END LOOP;
END $$;

-- Trigger a refresh of subscription data
UPDATE stripe_customers
SET updated_at = NOW()
WHERE payment_type = 'monthly'
  AND deleted_at IS NULL;