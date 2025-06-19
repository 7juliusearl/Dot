-- Check what columns actually exist in the stripe tables

-- 1. Check stripe_customers table structure
SELECT 'stripe_customers table columns:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'stripe_customers' 
ORDER BY ordinal_position;

-- 2. Check stripe_orders table structure  
SELECT 'stripe_orders table columns:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'stripe_orders' 
ORDER BY ordinal_position;

-- 3. Show sample data from stripe_customers
SELECT 'Sample stripe_customers data:' as info;
SELECT * FROM stripe_customers LIMIT 3;

-- 4. Show sample data from stripe_orders
SELECT 'Sample stripe_orders data:' as info;  
SELECT * FROM stripe_orders LIMIT 3;

-- 5. Check for the specific customer
SELECT 'Specific customer cus_SROKz1r6tv7kzd:' as info;
SELECT * FROM stripe_customers WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 6. Check for orders for this customer
SELECT 'Orders for customer cus_SROKz1r6tv7kzd:' as info;
SELECT * FROM stripe_orders WHERE customer_id = 'cus_SROKz1r6tv7kzd'; 