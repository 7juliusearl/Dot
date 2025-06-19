-- Check if these specific lifetime customers exist in our database
SELECT 
  email,
  purchase_type,
  amount_total/100.0 as amount_dollars,
  payment_status,
  status,
  created_at,
  checkout_session_id,
  customer_id
FROM stripe_orders 
WHERE email IN ('jenkad44@gmail.com', 'amanda.petruescu@gmail.com')
ORDER BY email;

-- Check if they exist with different purchase types
SELECT 
  email,
  purchase_type,
  COUNT(*) as order_count,
  STRING_AGG(amount_total::text, ', ') as amounts
FROM stripe_orders 
WHERE email IN ('jenkad44@gmail.com', 'amanda.petruescu@gmail.com')
GROUP BY email, purchase_type;

-- Also check if they might be in stripe_subscriptions table (by customer_id)
-- First, let's see what columns exist in stripe_subscriptions
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'stripe_subscriptions';

-- Check stripe_subscriptions for these customers (we'll need to join with orders to get emails)
SELECT 
  s.status,
  s.customer_id,
  s.subscription_id,
  s.created_at,
  o.email
FROM stripe_subscriptions s
LEFT JOIN stripe_orders o ON s.customer_id = o.customer_id
WHERE o.email IN ('jenkad44@gmail.com', 'amanda.petruescu@gmail.com'); 