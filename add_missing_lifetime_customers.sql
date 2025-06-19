-- Add missing lifetime customers to stripe_orders table
-- jenkad44@gmail.com and amanda.petruescu@gmail.com

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
) VALUES 
(
  'pi_3RWWJ1InTpoMSXou0S1NAljb', -- Using payment intent as session ID since we don't have checkout session
  'pi_3RWWJ1InTpoMSXou0S1NAljb',
  'cus_SRP6Ip9KVxeQ5j',
  2799, -- $27.99 in cents
  2799, -- $27.99 in cents
  'usd',
  'paid',
  'completed',
  'lifetime',
  'jenkad44@gmail.com'
),
(
  'pi_3RWWVzInTpoMSXou2Kv88zEC', -- Using payment intent as session ID since we don't have checkout session
  'pi_3RWWVzInTpoMSXou2Kv88zEC',
  'cus_SRPJdyHQH9VCTV',
  2799, -- $27.99 in cents
  2799, -- $27.99 in cents
  'usd',
  'paid',
  'completed',
  'lifetime',
  'amanda.petruescu@gmail.com'
);

-- Verify the insertions worked
SELECT 
  email,
  purchase_type,
  amount_total/100.0 as amount_dollars,
  payment_status,
  status,
  created_at
FROM stripe_orders 
WHERE email IN ('jenkad44@gmail.com', 'amanda.petruescu@gmail.com')
ORDER BY email; 