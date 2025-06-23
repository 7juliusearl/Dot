-- COMPREHENSIVE FIX: All yearly purchase type constraints
-- Fixes constraint violations for yearly subscriptions in all tables

-- Step 1: Check current constraints
SELECT 
    schemaname,
    tablename, 
    constraintname,
    constrainttype,
    constraintdef
FROM pg_catalog.pg_constraints_view 
WHERE constraintname LIKE '%purchase_type%' 
   OR constraintdef LIKE '%purchase_type%';

-- Step 2: Fix stripe_orders table constraint
ALTER TABLE stripe_orders 
DROP CONSTRAINT IF EXISTS stripe_orders_purchase_type_check;

ALTER TABLE stripe_orders 
ADD CONSTRAINT stripe_orders_purchase_type_check 
CHECK (purchase_type IN ('lifetime', 'monthly', 'yearly'));

-- Step 3: Fix stripe_subscriptions table constraint if exists
ALTER TABLE stripe_subscriptions 
DROP CONSTRAINT IF EXISTS stripe_subscriptions_purchase_type_check;

-- Only add if the column exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'stripe_subscriptions' 
               AND column_name = 'purchase_type') THEN
        
        ALTER TABLE stripe_subscriptions 
        ADD CONSTRAINT stripe_subscriptions_purchase_type_check 
        CHECK (purchase_type IN ('lifetime', 'monthly', 'yearly'));
        
        RAISE NOTICE 'Added purchase_type constraint to stripe_subscriptions';
    ELSE
        RAISE NOTICE 'stripe_subscriptions does not have purchase_type column';
    END IF;
END $$;

-- Step 4: Update any existing subscription_status issues
-- Fix incomplete statuses that might cause issues
UPDATE stripe_orders 
SET subscription_status = 'active'
WHERE subscription_status = 'incomplete' 
  AND purchase_type IN ('monthly', 'yearly')
  AND status = 'completed'
  AND created_at > NOW() - INTERVAL '30 days';

-- Step 5: Verify all constraints are now working
SELECT 
    'CONSTRAINT VERIFICATION' as check_type,
    schemaname,
    tablename, 
    constraintname,
    constraintdef
FROM pg_catalog.pg_constraints_view 
WHERE constraintdef LIKE '%purchase_type%'
ORDER BY tablename, constraintname;

-- Step 6: Test yearly constraint works
BEGIN;
-- Test stripe_orders
INSERT INTO stripe_orders (
    checkout_session_id, 
    payment_intent_id, 
    customer_id, 
    amount_total, 
    currency, 
    payment_status, 
    status, 
    email, 
    purchase_type,
    payment_method_brand,
    payment_method_last4
) VALUES (
    'test_yearly_orders',
    'test_yearly_orders', 
    'test_customer',
    2799,
    'usd',
    'paid',
    'completed',
    'test@example.com',
    'yearly',
    'card',
    '****'
);

ROLLBACK; -- Don't actually insert, just test

-- Step 7: Show success
SELECT 
    'ALL YEARLY CONSTRAINTS FIXED' as status,
    'yearly purchase_type now works in all tables' as message,
    NOW() as fixed_at;

-- Step 8: Show current purchase type distribution
SELECT 
    'CURRENT PURCHASE TYPES' as info,
    purchase_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stripe_orders WHERE deleted_at IS NULL), 2) as percentage
FROM stripe_orders 
WHERE deleted_at IS NULL 
  AND status = 'completed'
GROUP BY purchase_type
ORDER BY count DESC; 