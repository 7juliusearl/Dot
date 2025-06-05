/*
  # Fix subscription data sync and display
  
  1. Changes
    - Add trigger to sync subscription data on order completion
    - Update existing subscription records with correct data
    - Ensure proper status display
  
  2. Security
    - Maintains existing RLS policies
*/

-- Update subscription status mapping
CREATE OR REPLACE FUNCTION map_stripe_subscription_status(status text)
RETURNS stripe_subscription_status
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE status
    WHEN 'trialing' THEN 'trialing'::stripe_subscription_status
    WHEN 'active' THEN 'active'::stripe_subscription_status
    WHEN 'canceled' THEN 'canceled'::stripe_subscription_status
    WHEN 'incomplete' THEN 'incomplete'::stripe_subscription_status
    WHEN 'incomplete_expired' THEN 'incomplete_expired'::stripe_subscription_status
    WHEN 'past_due' THEN 'past_due'::stripe_subscription_status
    WHEN 'unpaid' THEN 'unpaid'::stripe_subscription_status
    ELSE 'not_started'::stripe_subscription_status
  END;
$$;

-- Update existing subscription records
UPDATE stripe_subscriptions
SET status = map_stripe_subscription_status('active')
WHERE status = 'not_started'
AND customer_id IN (
  SELECT customer_id 
  FROM stripe_orders 
  WHERE status = 'completed'
);

-- Create function to sync subscription data
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
      map_stripe_subscription_status('active'),
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
      SUBSTRING(NEW.payment_intent_id FROM '.{4}$')
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
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for order completion
DROP TRIGGER IF EXISTS sync_subscription_on_order_complete ON stripe_orders;
CREATE TRIGGER sync_subscription_on_order_complete
  AFTER INSERT OR UPDATE OF status ON stripe_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION sync_subscription_data();

-- Update existing completed orders to trigger sync
UPDATE stripe_orders
SET updated_at = NOW()
WHERE status = 'completed'
AND deleted_at IS NULL;