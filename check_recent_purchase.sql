-- 🔍 CHECK RECENT LIFETIME PURCHASE
-- Find the most recent lifetime purchase and check payment method data

SELECT 
  created_at,
  email,
  customer_id,
  purchase_type,
  payment_method_brand,
  payment_method_last4,
  amount_total / 100.0 as amount_dollars,
  payment_status,
  status
FROM stripe_orders 
WHERE purchase_type = 'lifetime'
  AND status = 'completed'
ORDER BY created_at DESC 
LIMIT 3;

-- Also check if there are any recent orders with placeholder data
SELECT 
  'Recent orders with placeholder data' as info,
  COUNT(*) as count
FROM stripe_orders 
WHERE payment_method_last4 = '****'
  AND created_at > NOW() - INTERVAL '1 hour'; 