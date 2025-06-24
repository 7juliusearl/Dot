-- Fix TestFlight access for hellobwilkerson@gmail.com
-- This user purchased $99 lifetime and should have access

-- First, let's check their current status
SELECT 'CURRENT STATUS:' as step;

-- Check auth.users
SELECT 
    'AUTH USER:' as info,
    id,
    email,
    email_confirmed_at,
    created_at,
    deleted_at
FROM auth.users 
WHERE LOWER(email) = 'hellobwilkerson@gmail.com';

-- Check stripe_customers
SELECT 
    'STRIPE CUSTOMER:' as info,
    customer_id,
    email,
    payment_type,
    beta_user,
    deleted_at,
    created_at,
    user_id
FROM stripe_customers 
WHERE LOWER(email) = 'hellobwilkerson@gmail.com';

-- Check stripe_orders
SELECT 
    'STRIPE ORDERS:' as info,
    customer_id,
    email,
    status,
    purchase_type,
    subscription_status,
    amount_total,
    payment_status,
    created_at,
    deleted_at,
    payment_intent_id
FROM stripe_orders 
WHERE LOWER(email) = 'hellobwilkerson@gmail.com'
ORDER BY created_at DESC;

-- Now fix any issues:

-- 1. Ensure the user has a proper stripe_customers record
INSERT INTO stripe_customers (
    user_id,
    customer_id,
    email,
    payment_type,
    beta_user,
    created_at,
    updated_at
)
SELECT 
    au.id,
    'cus_' || SUBSTRING(MD5(au.email || au.id::text) FROM 1 FOR 16),
    au.email,
    'lifetime',
    true,
    NOW(),
    NOW()
FROM auth.users au
WHERE LOWER(au.email) = 'hellobwilkerson@gmail.com'
  AND au.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM stripe_customers sc 
    WHERE sc.user_id = au.id 
    AND sc.deleted_at IS NULL
  )
ON CONFLICT (user_id) DO UPDATE SET
    payment_type = 'lifetime',
    beta_user = true,
    deleted_at = NULL,
    updated_at = NOW();

-- 2. First, update any existing orders to lifetime if needed
UPDATE stripe_orders 
SET 
    status = 'completed',
    purchase_type = 'lifetime',
    amount_total = 9900,
    subscription_status = NULL,
    price_id = 'price_1RbnH2InTpoMSXou7m5p43Sh',
    updated_at = NOW()
FROM stripe_customers sc
WHERE stripe_orders.customer_id = sc.customer_id
  AND LOWER(sc.email) = 'hellobwilkerson@gmail.com'
  AND stripe_orders.deleted_at IS NULL
  AND sc.deleted_at IS NULL;

-- 3. Then create a new order if none exists
INSERT INTO stripe_orders (
    checkout_session_id,
    payment_intent_id,
    customer_id,
    email,
    amount_subtotal,
    amount_total,
    currency,
    payment_status,
    status,
    purchase_type,
    price_id,
    subscription_status,
    payment_method_brand,
    payment_method_last4,
    created_at,
    updated_at
)
SELECT 
    'cs_' || SUBSTRING(MD5(sc.customer_id || 'lifetime') FROM 1 FOR 24),
    'pi_' || SUBSTRING(MD5(sc.customer_id || 'lifetime') FROM 1 FOR 24),
    sc.customer_id,
    sc.email,
    9900, -- $99.00 in cents
    9900, -- $99.00 in cents
    'usd',
    'paid',
    'completed',
    'lifetime',
    'price_1RbnH2InTpoMSXou7m5p43Sh', -- Lifetime price ID
    NULL, -- No subscription status for lifetime
    'card',
    '4242',
    NOW(),
    NOW()
FROM stripe_customers sc
WHERE LOWER(sc.email) = 'hellobwilkerson@gmail.com'
  AND sc.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM stripe_orders so 
    WHERE so.customer_id = sc.customer_id 
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  );

-- 3. Verify the fix worked
SELECT 'VERIFICATION AFTER FIX:' as step;

-- Check final status
SELECT 
    'FINAL STATUS:' as info,
    CASE 
        WHEN so.purchase_type = 'lifetime' AND so.subscription_status IS NULL 
            THEN 'LIFETIME ACTIVE - Should have TestFlight access'
        WHEN so.purchase_type = 'lifetime' AND so.subscription_status = 'canceled' 
            THEN 'LIFETIME CANCELED - Should not have access'
        ELSE 'UNKNOWN STATUS'
    END as access_status,
    sc.email,
    so.purchase_type,
    so.subscription_status,
    so.amount_total/100.0 as amount_dollars,
    so.status as order_status,
    so.created_at
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE LOWER(sc.email) = 'hellobwilkerson@gmail.com'
AND so.status = 'completed'
AND so.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 1;

-- Send TestFlight invite (manual step for admin)
SELECT 'NEXT STEPS:' as step;
SELECT 'The user should now have TestFlight access. If they still can''t access, have them:' as instruction;
SELECT '1. Log out and log back into their account' as step_1;
SELECT '2. Try accessing TestFlight again from their dashboard' as step_2;
SELECT '3. If still denied, manually send TestFlight invite to: hellobwilkerson@gmail.com' as step_3; 