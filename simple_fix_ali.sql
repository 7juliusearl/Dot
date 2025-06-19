-- Step 1: Fix the trigger function to handle different enum types
CREATE OR REPLACE FUNCTION notify_payment_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'stripe_orders' THEN
    IF NEW.status::text = 'completed' THEN
      PERFORM pg_notify('payment_completed', NEW.email);
    END IF;
  END IF;
  
  IF TG_TABLE_NAME = 'stripe_subscriptions' THEN
    IF NEW.status::text = 'active' THEN
      PERFORM pg_notify('subscription_activated', NEW.customer_id);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Insert Ali's missing order record
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

-- Step 3: Verify Ali now has access
SELECT email, 'SUCCESS - Ali can now access subscription' as status 
FROM stripe_orders 
WHERE email = 'ali@mossandelder.com'; 