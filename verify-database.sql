-- Verify Database Schema for Customer Mapping Fix
-- Run this in Supabase SQL Editor to check if the fix will work

-- 1. Check stripe_customers table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'stripe_customers'
ORDER BY ordinal_position;

-- 2. Check if email column exists and is properly configured
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'stripe_customers' 
            AND column_name = 'email'
        ) 
        THEN '✅ Email column exists'
        ELSE '❌ Email column missing - this will cause the error!'
    END as email_check;

-- 3. Check if beta_user and payment_type columns exist
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'stripe_customers' 
            AND column_name = 'beta_user'
        ) 
        THEN '✅ beta_user column exists'
        ELSE '❌ beta_user column missing'
    END as beta_user_check;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'stripe_customers' 
            AND column_name = 'payment_type'
        ) 
        THEN '✅ payment_type column exists'
        ELSE '❌ payment_type column missing'
    END as payment_type_check;

-- 4. Test insert simulation (this won't actually insert, just checks syntax)
EXPLAIN (FORMAT JSON) 
INSERT INTO stripe_customers (
    user_id, 
    customer_id, 
    email, 
    beta_user, 
    payment_type
) VALUES (
    'test-user-id'::uuid,
    'test-customer-id',
    'test@example.com',
    true,
    'monthly'
);

-- 5. Check recent customer records to see data quality
SELECT 
    user_id,
    customer_id,
    email,
    beta_user,
    payment_type,
    created_at
FROM stripe_customers 
WHERE deleted_at IS NULL 
ORDER BY created_at DESC 
LIMIT 5; 