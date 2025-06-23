-- IMMEDIATE FIX: Add yearly to purchase_type constraint
-- This fixes the constraint violation error for yearly subscriptions

-- Step 1: Check current constraint
SELECT conname, consrc 
FROM pg_constraint 
WHERE conname = 'stripe_orders_purchase_type_check';

-- Step 2: Drop the existing constraint that's blocking yearly
ALTER TABLE stripe_orders 
DROP CONSTRAINT IF EXISTS stripe_orders_purchase_type_check;

-- Step 3: Add new constraint that includes yearly
ALTER TABLE stripe_orders 
ADD CONSTRAINT stripe_orders_purchase_type_check 
CHECK (purchase_type IN ('lifetime', 'monthly', 'yearly'));

-- Step 4: Verify the fix
SELECT conname, consrc 
FROM pg_constraint 
WHERE conname = 'stripe_orders_purchase_type_check';

-- Step 5: Test with a sample insert (will rollback)
BEGIN;
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
    'test_yearly_constraint',
    'test_yearly_constraint', 
    'test_customer',
    2799,
    'usd',
    'paid',
    'completed',
    'test@example.com',
    'yearly',  -- This should now work
    'card',
    '****'
);
ROLLBACK; -- Don't actually insert, just test the constraint

-- Step 6: Show success message
SELECT 'YEARLY CONSTRAINT FIX COMPLETE' as status,
       'yearly purchase_type is now allowed' as message; 