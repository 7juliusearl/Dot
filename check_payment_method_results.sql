-- ✅ CHECK PAYMENT METHOD SYNC RESULTS
-- Run this to see the current status of your customers' payment method data

-- Step 1: Check current payment method data for your batch
SELECT 
    '🔍 CURRENT PAYMENT METHOD STATUS' as status_check,
    so.email,
    so.customer_id,
    so.purchase_type,
    so.payment_method_brand,
    so.payment_method_last4,
    CASE 
        WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN '✅ HAS REAL CARD DIGITS'
        WHEN so.payment_method_last4 = '****' THEN '⚠️ STILL NEEDS SYNC'
        ELSE '❌ INVALID DATA'
    END as sync_status,
    so.created_at,
    so.updated_at
FROM stripe_orders so
WHERE so.customer_id IN (
    'cus_SYTcC4irOkLilX',  -- sarahdeloachphotography@gmail.com
    'cus_SYOlI54YnfORSB',  -- ambergcphotos@gmail.com  
    'cus_SYOpAgoMKUl6jA',  -- nic.dampier@gmail.com
    'cus_SYNoUuO1DZfCkx',  -- lunuphotography@gmail.com
    'cus_SYLdNppx7h9O0g',  -- madisonhernandezphotography@gmail.com
    'cus_SYL3wPUyfhaAMJ',  -- sammy@scoylephoto.com
    'cus_SYKpQEtSq8KAnO',  -- lkdanielphotography@gmail.com
    'cus_SYIqIrOdyoDljg',  -- christa@christaandcophoto.com
    'cus_SYHXPA4yxz6cde',  -- kendrickjlittle1@gmail.com
    'cus_SYFSaOLJ3AFVRl'   -- contact@emerlinphotography.com
)
AND so.status = 'completed'
ORDER BY so.updated_at DESC;

-- Step 2: Summary statistics
SELECT 
    '📊 SYNC PROGRESS SUMMARY' as summary_type,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as orders_with_real_data,
    COUNT(CASE WHEN so.payment_method_last4 = '****' THEN 1 END) as orders_still_needing_sync,
    ROUND(
        (COUNT(CASE WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2
    ) as success_percentage
FROM stripe_orders so
WHERE so.customer_id IN (
    'cus_SYTcC4irOkLilX', 'cus_SYOlI54YnfORSB', 'cus_SYOpAgoMKUl6jA',  
    'cus_SYNoUuO1DZfCkx', 'cus_SYLdNppx7h9O0g', 'cus_SYL3wPUyfhaAMJ',
    'cus_SYKpQEtSq8KAnO', 'cus_SYIqIrOdyoDljg', 'cus_SYHXPA4yxz6cde',
    'cus_SYFSaOLJ3AFVRl'
)
AND so.status = 'completed';

-- Step 3: Manual sync instructions for remaining customers
SELECT 
    '📋 MANUAL SYNC INSTRUCTIONS' as instructions_title,
    'For customers still showing ****, use Supabase Dashboard to run sync function' as step_1,
    'Go to Supabase Dashboard → Edge Functions → sync-payment-methods' as step_2,
    'Run function with: {"action": "sync_single_customer", "customer_id": "cus_..."}' as step_3;

-- Step 4: Show customers that still need sync
SELECT 
    '🎯 CUSTOMERS STILL NEEDING SYNC' as remaining_work,
    so.customer_id,
    so.email,
    so.purchase_type,
    'Use this customer_id in sync function' as action_needed
FROM stripe_orders so
WHERE so.customer_id IN (
    'cus_SYTcC4irOkLilX', 'cus_SYOlI54YnfORSB', 'cus_SYOpAgoMKUl6jA',  
    'cus_SYNoUuO1DZfCkx', 'cus_SYLdNppx7h9O0g', 'cus_SYL3wPUyfhaAMJ',
    'cus_SYKpQEtSq8KAnO', 'cus_SYIqIrOdyoDljg', 'cus_SYHXPA4yxz6cde',
    'cus_SYFSaOLJ3AFVRl'
)
AND so.status = 'completed'
AND so.payment_method_last4 = '****'
ORDER BY so.created_at DESC; 