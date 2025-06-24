-- Find ALL lifetime purchasers who are incorrectly showing as "Monthly" in dashboard
-- This happens when purchase_type is correct but payment_type in customers table is wrong

-- 1. Find the problem: Users who purchased lifetime but customer record shows monthly
SELECT 
    'LIFETIME PURCHASERS WITH WRONG PAYMENT_TYPE:' as issue,
    sc.email,
    sc.customer_id,
    sc.payment_type as customer_payment_type,
    so.purchase_type as order_purchase_type,
    so.amount_total / 100.0 as amount_paid_dollars,
    so.status as order_status,
    so.created_at as purchase_date
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.purchase_type = 'lifetime'  -- They bought lifetime
  AND sc.payment_type != 'lifetime'  -- But customer record is wrong
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL
ORDER BY so.created_at DESC;

-- 2. Count how many users are affected
SELECT 
    'SUMMARY:' as info,
    COUNT(*) as total_lifetime_purchasers_with_wrong_customer_type
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.purchase_type = 'lifetime'
  AND sc.payment_type != 'lifetime'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL;

-- 3. Also check for the opposite problem: customers marked lifetime but no lifetime order
SELECT 
    'CUSTOMERS MARKED LIFETIME WITHOUT LIFETIME ORDER:' as issue,
    sc.email,
    sc.customer_id,
    sc.payment_type as customer_payment_type,
    so.purchase_type as order_purchase_type,
    so.amount_total / 100.0 as amount_paid_dollars
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id AND so.purchase_type = 'lifetime' AND so.status = 'completed' AND so.deleted_at IS NULL
WHERE sc.payment_type = 'lifetime'
  AND sc.deleted_at IS NULL
  AND so.purchase_type IS NULL  -- No lifetime order found
ORDER BY sc.created_at DESC;

-- 4. FIX: Update all customer records to match their actual purchase type
-- IMPORTANT: stripe_customers.payment_type constraint only allows 'lifetime' and 'monthly'
-- So we map: lifetime → 'lifetime', yearly → 'monthly', monthly → 'monthly'
UPDATE stripe_customers 
SET 
    payment_type = CASE 
        WHEN so.purchase_type = 'lifetime' THEN 'lifetime'
        WHEN so.purchase_type = 'yearly' THEN 'monthly'  -- Yearly maps to monthly in customer table
        WHEN so.purchase_type = 'monthly' THEN 'monthly'
        ELSE 'monthly'  -- Default fallback
    END,
    updated_at = NOW()
FROM stripe_orders so
WHERE stripe_customers.customer_id = so.customer_id
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND stripe_customers.deleted_at IS NULL
  AND stripe_customers.payment_type != CASE 
        WHEN so.purchase_type = 'lifetime' THEN 'lifetime'
        WHEN so.purchase_type = 'yearly' THEN 'monthly'
        WHEN so.purchase_type = 'monthly' THEN 'monthly'
        ELSE 'monthly'
    END
  AND so.id = (
    -- Get the most recent completed order for this customer
    SELECT id FROM stripe_orders so2 
    WHERE so2.customer_id = stripe_customers.customer_id 
      AND so2.status = 'completed' 
      AND so2.deleted_at IS NULL 
    ORDER BY so2.created_at DESC 
    LIMIT 1
  );

-- Count will be shown in the SQL output as "UPDATE X"
SELECT 'CUSTOMER PAYMENT_TYPES UPDATE COMPLETED' as result;

-- 5. Verification: Check that the fix worked
SELECT 
    'VERIFICATION AFTER FIX:' as step,
    sc.email,
    sc.payment_type as customer_payment_type,
    so.purchase_type as order_purchase_type,
    CASE 
        WHEN so.purchase_type = 'lifetime' AND sc.payment_type = 'lifetime' THEN '✅ FIXED'
        WHEN so.purchase_type = 'yearly' AND sc.payment_type = 'monthly' THEN '✅ FIXED (yearly→monthly)'
        WHEN so.purchase_type = 'monthly' AND sc.payment_type = 'monthly' THEN '✅ FIXED'
        ELSE '❌ STILL WRONG'
    END as status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 20;

-- 6. Final count of lifetime users
SELECT 
    'FINAL COUNTS:' as info,
    COUNT(CASE WHEN so.purchase_type = 'lifetime' THEN 1 END) as total_lifetime_orders,
    COUNT(CASE WHEN sc.payment_type = 'lifetime' THEN 1 END) as total_lifetime_customers,
    COUNT(CASE WHEN so.purchase_type = 'lifetime' AND sc.payment_type = 'lifetime' THEN 1 END) as correctly_marked_lifetime_users
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL; 