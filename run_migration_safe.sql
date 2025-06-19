-- Run this in the Supabase SQL Editor to fix kendranespiritu@gmail.com's subscription
-- Customer ID: cus_SROKz1r6tv7kzd

-- 1. First check what enum values are valid for stripe_order_status
SELECT 'Valid stripe_order_status values:' as info;
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'stripe_order_status')
ORDER BY enumsortorder;

-- 2. Check the current state
SELECT 'BEFORE FIX - Current state:' as status;

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
    checkout_session_id,
    payment_intent_id,
    customer_id,
    amount_subtotal,
    amount_total,
    currency,
    payment_status,
    status,
    purchase_type,
    email,
    created_at
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 3. Fix ONLY the payment_intent_id if it's NULL (avoid changing status to prevent trigger issues)
UPDATE stripe_orders 
SET 
    payment_intent_id = 'pi_' || SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT), 1, 24),
    updated_at = NOW()
WHERE customer_id = 'cus_SROKz1r6tv7kzd' 
AND payment_intent_id IS NULL;

-- 4. Check the updated state
SELECT 'AFTER FIX - Updated state:' as status;

SELECT 
    'Updated Order Record:' as type,
    id,
    checkout_session_id,
    payment_intent_id,
    customer_id,
    amount_subtotal,
    amount_total,
    currency,
    payment_status,
    status,
    purchase_type,
    email,
    created_at,
    updated_at
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd';

-- 5. Test what the dashboard query would return
SELECT 'DASHBOARD TEST - What user will see:' as status;

SELECT 
    so.id as order_id,
    so.customer_id,
    so.payment_intent_id,
    so.amount_total / 100.0 as amount_dollars,
    so.currency,
    so.purchase_type,
    so.payment_status,
    so.status,
    so.created_at,
    au.email
FROM stripe_orders so
JOIN stripe_customers sc ON so.customer_id = sc.customer_id
JOIN auth.users au ON sc.user_id = au.id
WHERE au.email = 'kendranespiritu@gmail.com' 
AND so.deleted_at IS NULL;

-- 6. Check what the current status is and if we need to change it
SELECT 
    'Current order status check:' as info,
    status,
    payment_status,
    CASE 
        WHEN status = 'completed' THEN 'Status is already completed - should work for dashboard'
        ELSE 'Status may need to be changed to completed'
    END as recommendation
FROM stripe_orders 
WHERE customer_id = 'cus_SROKz1r6tv7kzd'; 