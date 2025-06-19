-- Debug the Dashboard component query to see what's happening
-- The Dashboard is querying: SELECT * FROM stripe_orders WHERE status = 'completed' ORDER BY created_at DESC LIMIT 1

-- 1. Check what the Dashboard query returns (this is the EXACT query the frontend uses)
SELECT 'DASHBOARD QUERY RESULT - What the frontend sees:' as info;
SELECT *
FROM stripe_orders
WHERE status = 'completed'
ORDER BY created_at DESC
LIMIT 1;

-- 2. Check if kendranespiritu@gmail.com's order exists and what status it has
SELECT 'KENDRA ORDER SPECIFIC CHECK:' as info;
SELECT 
    so.*,
    sc.email,
    au.email as auth_email
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id  
JOIN auth.users au ON sc.user_id = au.id
WHERE au.email = 'kendranespiritu@gmail.com';

-- 3. Check ALL completed orders to see if there are others
SELECT 'ALL COMPLETED ORDERS:' as info;
SELECT 
    so.id,
    so.customer_id,
    so.payment_intent_id,
    so.amount_total,
    so.purchase_type,
    so.status,
    so.created_at,
    sc.email,
    au.email as auth_email
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
LEFT JOIN auth.users au ON sc.user_id = au.id
WHERE so.status = 'completed'
ORDER BY so.created_at DESC;

-- 4. Check if RLS is blocking the user from seeing their own data
SELECT 'RLS POLICY CHECK:' as info;
SELECT schemaname, tablename, policyname, roles, cmd, qual
FROM pg_policies 
WHERE tablename IN ('stripe_orders', 'stripe_customers')
ORDER BY tablename, policyname;

-- 5. Test if the user can see their own order (simulating frontend query with RLS)
SET ROLE authenticated;
SELECT 'USER CAN SEE THEIR ORDER (with RLS):' as info;
SELECT *
FROM stripe_orders
WHERE customer_id = 'cus_SROKz1r6tv7kzd'
AND status = 'completed';

-- Reset role
RESET ROLE; 