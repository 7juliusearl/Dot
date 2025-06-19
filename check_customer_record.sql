-- Check the specific customer record for kendranespiritu@gmail.com
-- Customer ID: cus_SROKz1r6tv7kzd

-- 1. Check the user record
SELECT 
    id,
    email,
    created_at,
    email_confirmed_at
FROM auth.users 
WHERE email = 'kendranespiritu@gmail.com';

-- 2. Check stripe_customers table
SELECT *
FROM stripe_customers
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 3. Check stripe_orders table  
SELECT *
FROM stripe_orders
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 4. Check what the dashboard query would return for this user
-- This is the exact query the Dashboard component uses
WITH user_customer AS (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE user_id = (
        SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com'
    )
)
SELECT 
    so.id,
    so.customer_id,
    so.payment_id,
    so.amount,
    so.currency,
    so.product_type,
    so.status,
    so.created_at,
    sc.user_id
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
WHERE so.customer_id IN (SELECT customer_id FROM user_customer)
AND so.status = 'completed';

-- 5. Check if there are any RLS policy issues by checking as different roles
SELECT current_user, current_setting('role');

-- 6. Check RLS policies on stripe_orders
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'stripe_orders';

-- 7. Check RLS policies on stripe_customers  
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'stripe_customers'; 