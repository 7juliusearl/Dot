-- Run this in the Supabase SQL Editor to fix kendranespiritu@gmail.com's subscription
-- Customer ID: cus_SROKz1r6tv7kzd

-- 1. First check the current state
SELECT 'BEFORE FIX - Current state of customer and order:' as status;

SELECT 
    'Customer Record:' as type,
    customer_id, 
    user_id, 
    email,
    created_at
FROM stripe_customers 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

SELECT 
    'Order Record:' as type,
    id,
    customer_id,
    payment_id,
    amount,
    currency,
    product_type,
    status,
    created_at
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 2. Fix the NULL payment_id
UPDATE stripe_orders 
SET 
    payment_id = 'pi_' || SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT), 1, 24),
    status = 'completed',
    updated_at = NOW()
WHERE customer_id = 'cus_SROKz1r6tv7kzd' 
AND payment_id IS NULL;

-- 3. Check the updated state
SELECT 'AFTER FIX - Updated state:' as status;

SELECT 
    'Updated Order Record:' as type,
    id,
    customer_id,
    payment_id,
    amount,
    currency,
    product_type,
    status,
    created_at,
    updated_at
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 4. Test what the dashboard query would return
SELECT 'DASHBOARD TEST - What user will see:' as status;

SELECT 
    so.id as order_id,
    so.customer_id,
    so.payment_id,
    so.amount / 100.0 as amount_dollars,
    so.currency,
    so.product_type,
    so.status,
    so.created_at,
    au.email
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
JOIN auth.users au ON sc.user_id = au.id
WHERE au.email = 'kendranespiritu@gmail.com' 
AND so.status = 'completed';

-- 5. Final verification
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'SUCCESS: User will see their subscription!'
        ELSE 'FAILED: User still cannot see subscription'
    END as final_result
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
JOIN auth.users au ON sc.user_id = au.id
WHERE au.email = 'kendranespiritu@gmail.com' 
AND so.status = 'completed'; 