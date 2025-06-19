-- Check valid enum values in stripe_orders
SELECT DISTINCT status FROM stripe_orders;

-- Also check the enum definition
SELECT 
    enumlabel 
FROM pg_enum 
WHERE enumtypid = (
    SELECT oid 
    FROM pg_type 
    WHERE typname = 'stripe_order_status'
); 