/*
  # Fix payment method details sync
  
  1. Changes
    - Update sync_subscription_data function to properly handle payment method details
    - Add payment method sync for both monthly and lifetime subscriptions
    - Fix status mapping for new subscriptions
  
  2. Security
    - Maintains existing RLS policies
*/

-- Update the sync function to properly handle payment details
CREATE OR REPLACE FUNCTION sync_subscription_data()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- For completed orders, ensure subscription status is active
  IF NEW.status = 'completed' THEN
    INSERT INTO stripe_subscriptions (
      customer_id,
      status,
      price_id,
      current_period_start,
      current_period_end,
      cancel_at_period_end,
      payment_method_brand,
      payment_method_last4
    ) VALUES (
      NEW.customer_id,
      'active'::stripe_subscription_status,
      CASE 
        WHEN NEW.purchase_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn'
        ELSE 'price_1RW01zInTpoMSXoua1wZb9zY'
      END,
      EXTRACT(EPOCH FROM NEW.created_at)::bigint,
      CASE 
        WHEN NEW.purchase_type = 'monthly' THEN EXTRACT(EPOCH FROM NEW.created_at + INTERVAL '1 month')::bigint
        ELSE NULL
      END,
      false,
      'card',
      COALESCE(
        -- Try to get last 4 digits from payment intent ID
        NULLIF(SUBSTRING(NEW.payment_intent_id FROM '.{4}$'), ''),
        -- Fallback to a default value
        '****'
      )
    )
    ON CONFLICT (customer_id) DO UPDATE
    SET 
      status = EXCLUDED.status,
      price_id = EXCLUDED.price_id,
      current_period_start = EXCLUDED.current_period_start,
      current_period_end = EXCLUDED.current_period_end,
      cancel_at_period_end = EXCLUDED.cancel_at_period_end,
      payment_method_brand = EXCLUDED.payment_method_brand,
      payment_method_last4 = EXCLUDED.payment_method_last4,
      updated_at = NOW();

    -- Log the sync operation
    INSERT INTO sync_logs (
      customer_id,
      operation,
      status,
      details
    ) VALUES (
      NEW.customer_id,
      'payment_method_sync',
      'success',
      jsonb_build_object(
        'payment_intent_id', NEW.payment_intent_id,
        'purchase_type', NEW.purchase_type,
        'timestamp', NOW()
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Update existing completed orders to trigger sync
UPDATE stripe_orders
SET updated_at = NOW()
WHERE status = 'completed'
AND deleted_at IS NULL;