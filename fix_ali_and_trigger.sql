-- Fix the trigger function - simplified version to avoid JSON syntax issues
CREATE OR REPLACE FUNCTION notify_payment_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle stripe_orders table (uses stripe_order_status enum)
  IF TG_TABLE_NAME = 'stripe_orders' THEN
    IF NEW.status::text = 'completed' THEN
      -- Send simple notification for completed order
      PERFORM pg_notify('payment_completed', NEW.email || ':' || NEW.customer_id);
    END IF;
  END IF;
  
  -- Handle stripe_subscriptions table (uses different enum/text)
  IF TG_TABLE_NAME = 'stripe_subscriptions' THEN
    IF NEW.status::text = 'active' THEN
      -- Send simple notification for active subscription
      PERFORM pg_notify('subscription_activated', COALESCE(NEW.email, NEW.customer_id));
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Now safely insert Ali's order record
INSERT INTO stripe_orders (
  checkout_session_id, 
  payment_intent_id, 
  customer_id, 
  amount_subtotal, 
  amount_total, 
  currency, 
  payment_status, 
  status, 
  purchase_type, 
  email
) VALUES (
  'cs_live_b1JIr1pgimXLuTfpSCl99h6DFTjsJprRuQTe0CS6qjX5KsQW425tSP8ASZ',
  'pi_3RWWnQInTpoMSXou2g80Ymke',
  'cus_SRPbc4DEJouCjg',
  399,
  399,
  'usd',
  'paid',
  'completed',
  'monthly',
  'ali@mossandelder.com'
);

-- Verify the insertion worked
SELECT * FROM stripe_orders WHERE email = 'ali@mossandelder.com';

-- Check if Ali now has access (should return true)
SELECT 
  email,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM stripe_orders so 
      WHERE so.email = 'ali@mossandelder.com' 
      AND so.status = 'completed'
    ) THEN 'HAS ACCESS ✅'
    ELSE 'NO ACCESS ❌'
  END as access_status
FROM (SELECT 'ali@mossandelder.com' as email) AS test; 