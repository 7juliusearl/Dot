-- Check what data exists in stripe_customers table
SELECT 
  customer_id,
  subscription_status,
  payment_type,
  beta_user,
  created_at
FROM stripe_customers 
ORDER BY created_at DESC 
LIMIT 10;

-- Count all records
SELECT COUNT(*) as total_customers FROM stripe_customers;

-- Count by subscription_status
SELECT 
  subscription_status,
  COUNT(*) as count
FROM stripe_customers 
GROUP BY subscription_status;

-- Count by payment_type
SELECT 
  payment_type,
  COUNT(*) as count
FROM stripe_customers 
GROUP BY payment_type;

-- The exact query we're using in the app
SELECT COUNT(*) as active_paying_customers
FROM stripe_customers 
WHERE subscription_status = 'active' 
   OR payment_type = 'lifetime'; 