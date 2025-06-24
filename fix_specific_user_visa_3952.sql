-- Fix the specific user shown in the screenshot with Visa card ending in 3952
-- They purchased lifetime but dashboard shows "Monthly"

-- 1. Find the user with Visa ending in 3952
SELECT 
    'FOUND USER WITH VISA 3952:' as step,
    sc.email,
    sc.customer_id,
    sc.payment_type as customer_payment_type,
    so.purchase_type as order_purchase_type,
    so.amount_total / 100.0 as amount_paid,
    so.payment_method_brand,
    so.payment_method_last4,
    so.created_at
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.payment_method_last4 = '3952'
  AND so.payment_method_brand = 'visa'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL;

-- 2. Check if they have a lifetime order but wrong customer type
SELECT 
    'DIAGNOSIS:' as step,
    sc.email,
    sc.payment_type as customer_shows,
    so.purchase_type as actually_purchased,
    so.amount_total / 100.0 as amount_paid,
    CASE 
        WHEN so.purchase_type = 'lifetime' AND sc.payment_type != 'lifetime' 
            THEN '❌ BUG: Lifetime purchaser showing as Monthly'
        WHEN so.purchase_type = 'lifetime' AND sc.payment_type = 'lifetime' 
            THEN '✅ Correct: Lifetime user properly marked'
        ELSE '⚠️ Other issue'
    END as diagnosis
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.payment_method_last4 = '3952'
  AND so.payment_method_brand = 'visa'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL;

-- 3. Fix the customer record to match their actual purchase
UPDATE stripe_customers 
SET 
    payment_type = 'lifetime',
    updated_at = NOW()
WHERE customer_id IN (
    SELECT sc.customer_id
    FROM stripe_customers sc
    JOIN stripe_orders so ON sc.customer_id = so.customer_id
    WHERE so.payment_method_last4 = '3952'
      AND so.payment_method_brand = 'visa'
      AND so.purchase_type = 'lifetime'
      AND so.status = 'completed'
      AND so.deleted_at IS NULL
      AND sc.deleted_at IS NULL
      AND sc.payment_type != 'lifetime'
);

SELECT 'FIXED USER WITH VISA 3952:' as result, ROW_COUNT() as users_updated;

-- 4. Verify the fix
SELECT 
    'VERIFICATION:' as step,
    sc.email,
    sc.payment_type as customer_type_now,
    so.purchase_type as order_type,
    so.amount_total / 100.0 as amount_paid,
    CASE 
        WHEN sc.payment_type = so.purchase_type THEN '✅ DASHBOARD WILL NOW SHOW CORRECTLY'
        ELSE '❌ STILL NEEDS FIXING'
    END as dashboard_status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.payment_method_last4 = '3952'
  AND so.payment_method_brand = 'visa'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL; 