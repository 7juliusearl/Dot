-- Create Ali's missing order record
-- Customer: ali@mossandelder.com (cus_SRPbc4DEJouCjg)

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
) 
SELECT 
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
WHERE NOT EXISTS (
  SELECT 1 FROM stripe_orders 
  WHERE email = 'ali@mossandelder.com' 
     OR customer_id = 'cus_SRPbc4DEJouCjg'
); 