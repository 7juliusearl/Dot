-- Check what purchase_type values we currently have
SELECT purchase_type, COUNT(*) as count 
FROM stripe_orders 
GROUP BY purchase_type;

-- Check for any orders with high amounts (likely lifetime)
SELECT 
  email,
  purchase_type,
  amount_total/100.0 as amount_dollars,
  payment_status,
  status,
  created_at,
  checkout_session_id
FROM stripe_orders 
WHERE amount_total > 1000  -- More than $10 (likely lifetime purchases)
ORDER BY created_at DESC;

-- Check recent orders to see pattern
SELECT 
  email,
  purchase_type,
  amount_total/100.0 as amount_dollars,
  created_at
FROM stripe_orders 
ORDER BY created_at DESC 
LIMIT 20; 