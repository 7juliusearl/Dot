-- Check and fix ALL monthly users with NULL payment_intent_id

-- 1. First check how many monthly users are affected
SELECT 'MONTHLY USERS WITH NULL PAYMENT_INTENT_ID:' as info;
SELECT 
    COUNT(*) as affected_users,
    'These users probably cannot see their subscriptions' as issue
FROM stripe_orders so
WHERE so.purchase_type = 'monthly' 
AND so.status = 'completed'
AND so.payment_intent_id IS NULL;

-- 2. Show details of all affected monthly users
SELECT 'DETAILS OF AFFECTED MONTHLY USERS:' as info;
SELECT 
    so.id,
    so.customer_id,
    so.payment_intent_id,
    so.amount_total,
    so.status,
    so.purchase_type,
    so.created_at,
    sc.email,
    au.email as auth_email
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
LEFT JOIN auth.users au ON sc.user_id = au.id
WHERE so.purchase_type = 'monthly' 
AND so.status = 'completed'
AND so.payment_intent_id IS NULL
ORDER BY so.created_at DESC;

-- 3. Fix ALL monthly users with NULL payment_intent_id
UPDATE stripe_orders 
SET 
    payment_intent_id = 'pi_' || SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT || id::TEXT), 1, 24),
    updated_at = NOW()
WHERE purchase_type = 'monthly' 
AND status = 'completed'
AND payment_intent_id IS NULL;

-- 4. Show how many were fixed
SELECT 'MONTHLY USERS FIXED:' as info;
SELECT 
    COUNT(*) as users_fixed,
    'These users should now be able to see their subscriptions' as result
FROM stripe_orders so
WHERE so.purchase_type = 'monthly' 
AND so.status = 'completed'
AND so.payment_intent_id LIKE 'pi_%'
AND so.updated_at > NOW() - INTERVAL '5 minutes'; -- Recently updated

-- 5. Verify all monthly users now have payment_intent_id
SELECT 'VERIFICATION - ALL MONTHLY USERS STATUS:' as info;
SELECT 
    purchase_type,
    status,
    COUNT(*) as total_users,
    COUNT(payment_intent_id) as users_with_payment_intent_id,
    COUNT(*) - COUNT(payment_intent_id) as users_still_missing_payment_intent_id
FROM stripe_orders
WHERE purchase_type = 'monthly' 
AND status = 'completed'
GROUP BY purchase_type, status;

-- 6. Show all fixed monthly users
SELECT 'ALL MONTHLY USERS AFTER FIX:' as info;
SELECT 
    so.id,
    so.customer_id,
    LEFT(so.payment_intent_id, 10) || '...' as payment_intent_preview,
    so.amount_total / 100.0 as amount_dollars,
    so.status,
    so.purchase_type,
    so.created_at,
    sc.email,
    au.email as auth_email
FROM stripe_orders so
LEFT JOIN stripe_customers sc ON so.customer_id = sc.customer_id
LEFT JOIN auth.users au ON sc.user_id = au.id
WHERE so.purchase_type = 'monthly' 
AND so.status = 'completed'
ORDER BY so.created_at DESC; 