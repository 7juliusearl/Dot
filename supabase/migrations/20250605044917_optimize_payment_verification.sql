-- Optimize payment verification performance
-- Add indexes and enable real-time replication for faster payment confirmation

-- Add indexes for faster payment verification queries
CREATE INDEX IF NOT EXISTS idx_stripe_customers_user_id_active 
ON stripe_customers(user_id) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_stripe_orders_customer_status_type 
ON stripe_orders(customer_id, status, purchase_type) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_stripe_subscriptions_customer_status 
ON stripe_subscriptions(customer_id, status) 
WHERE deleted_at IS NULL;

-- Enable real-time replication for payment verification tables
-- This allows Supabase real-time subscriptions to work efficiently
ALTER TABLE stripe_customers REPLICA IDENTITY FULL;
ALTER TABLE stripe_orders REPLICA IDENTITY FULL;
ALTER TABLE stripe_subscriptions REPLICA IDENTITY FULL;

-- Enable real-time on these tables (if not already enabled)
ALTER PUBLICATION supabase_realtime ADD TABLE stripe_customers;
ALTER PUBLICATION supabase_realtime ADD TABLE stripe_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE stripe_subscriptions;

-- Create a function to immediately notify payment completion
CREATE OR REPLACE FUNCTION notify_payment_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- For completed orders, perform immediate notification
  IF TG_TABLE_NAME = 'stripe_orders' AND NEW.status = 'completed' THEN
    -- Log immediate completion for faster polling detection
    INSERT INTO sync_logs (customer_id, operation, status, details)
    VALUES (
      NEW.customer_id,
      'payment_completed',
      'success',
      jsonb_build_object(
        'purchase_type', NEW.purchase_type,
        'payment_intent_id', NEW.payment_intent_id,
        'immediate_notification', true,
        'timestamp', NOW()
      )
    );
  END IF;
  
  -- For active subscriptions
  IF TG_TABLE_NAME = 'stripe_subscriptions' AND NEW.status = 'active' THEN
    INSERT INTO sync_logs (customer_id, operation, status, details)
    VALUES (
      NEW.customer_id,
      'subscription_activated',
      'success',
      jsonb_build_object(
        'subscription_id', NEW.subscription_id,
        'immediate_notification', true,
        'timestamp', NOW()
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create triggers for immediate notification
DROP TRIGGER IF EXISTS notify_payment_completion_orders ON stripe_orders;
CREATE TRIGGER notify_payment_completion_orders
  AFTER INSERT OR UPDATE OF status ON stripe_orders
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION notify_payment_completion();

DROP TRIGGER IF EXISTS notify_payment_completion_subscriptions ON stripe_subscriptions;
CREATE TRIGGER notify_payment_completion_subscriptions
  AFTER INSERT OR UPDATE OF status ON stripe_subscriptions
  FOR EACH ROW
  WHEN (NEW.status = 'active')
  EXECUTE FUNCTION notify_payment_completion();

-- Add comments for monitoring
COMMENT ON FUNCTION notify_payment_completion IS 'Triggers immediate notifications when payments are completed or subscriptions activated for faster frontend verification';
COMMENT ON TRIGGER notify_payment_completion_orders ON stripe_orders IS 'Notifies payment completion immediately for real-time updates';
COMMENT ON TRIGGER notify_payment_completion_subscriptions ON stripe_subscriptions IS 'Notifies subscription activation immediately for real-time updates';
