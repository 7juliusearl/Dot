-- Check what columns actually exist in stripe_orders table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'stripe_orders' 
ORDER BY ordinal_position;

-- Also show a sample record to see the data structure
SELECT * FROM stripe_orders WHERE customer_id = 'cus_SROKz1r6tv7kzd' LIMIT 1; 