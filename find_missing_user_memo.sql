-- Comprehensive search for memo.gsalinas@gmail.com or similar users
-- This script will help us understand why the user is missing and what to do about it

SELECT 'COMPREHENSIVE SEARCH FOR MEMO.GSALINAS@GMAIL.COM' as info;

-- 1. Check for exact email match (case sensitive)
SELECT 
  'EXACT EMAIL MATCH:' as search_type,
  COUNT(*) as found_count
FROM auth.users 
WHERE email = 'memo.gsalinas@gmail.com';

-- 2. Check for case variations
SELECT 
  'CASE VARIATIONS:' as search_type,
  email,
  id,
  created_at
FROM auth.users 
WHERE LOWER(email) = LOWER('memo.gsalinas@gmail.com')
   OR email ILIKE '%memo.gsalinas%'
   OR email ILIKE '%memo%gsalinas%';

-- 3. Check for similar emails (memo, gsalinas variations)
SELECT 
  'SIMILAR EMAILS:' as search_type,
  email,
  id,
  created_at
FROM auth.users 
WHERE email ILIKE '%memo%'
   OR email ILIKE '%gsalinas%'
   OR email ILIKE '%guillermo%' -- memo might be short for Guillermo
ORDER BY email;

-- 4. Check stripe_customers for any memo-related emails
SELECT 
  'STRIPE_CUSTOMERS SEARCH:' as search_type,
  email,
  customer_id,
  user_id,
  created_at
FROM stripe_customers 
WHERE email ILIKE '%memo%'
   OR email ILIKE '%gsalinas%'
   OR email ILIKE '%guillermo%'
ORDER BY email;

-- 5. Check stripe_orders for any memo-related emails (even without customer record)
SELECT 
  'STRIPE_ORDERS SEARCH:' as search_type,
  email,
  customer_id,
  status,
  purchase_type,
  amount_total,
  created_at
FROM stripe_orders 
WHERE email ILIKE '%memo%'
   OR email ILIKE '%gsalinas%'
   OR email ILIKE '%guillermo%'
ORDER BY email, created_at DESC;

-- 6. Look for recent users that might be memo (last 30 days)
SELECT 
  'RECENT USERS (LAST 30 DAYS):' as search_type,
  email,
  id,
  created_at
FROM auth.users 
WHERE created_at > NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

-- 7. Check for deleted/soft-deleted users
SELECT 
  'CHECKING FOR DELETED USERS:' as search_type,
  email,
  customer_id,
  user_id,
  created_at,
  deleted_at
FROM stripe_customers 
WHERE (email ILIKE '%memo%' OR email ILIKE '%gsalinas%')
   AND deleted_at IS NOT NULL;

-- 8. Show total user counts to understand the system size
SELECT 
  'SYSTEM OVERVIEW:' as info,
  (SELECT COUNT(*) FROM auth.users) as total_auth_users,
  (SELECT COUNT(*) FROM stripe_customers) as total_customers,
  (SELECT COUNT(*) FROM stripe_orders WHERE status = 'completed') as completed_orders;

-- 9. Show recent successful orders to see pattern
SELECT 
  'RECENT SUCCESSFUL ORDERS (LAST 10):' as info,
  email,
  customer_id,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  created_at
FROM stripe_orders 
WHERE status = 'completed'
  AND deleted_at IS NULL
ORDER BY created_at DESC 
LIMIT 10;

-- 10. Search for any customer with similar payment amounts (if we know what memo paid)
-- Common amounts: $49.99 lifetime, $9.99 monthly
SELECT 
  'CUSTOMERS WITH COMMON PAYMENT AMOUNTS:' as info,
  email,
  customer_id,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  created_at
FROM stripe_orders 
WHERE status = 'completed'
  AND (
    amount_total = 4999 -- $49.99 lifetime
    OR amount_total = 999 -- $9.99 monthly  
    OR amount_total = 5000 -- $50.00
    OR amount_total = 1000 -- $10.00
  )
  AND created_at > NOW() - INTERVAL '60 days' -- Recent payments
ORDER BY created_at DESC;

-- 11. Check what tables exist to ensure we're looking in the right places
SELECT 
  'AVAILABLE STRIPE TABLES:' as info,
  table_name,
  (
    SELECT COUNT(*) 
    FROM information_schema.columns 
    WHERE table_name = t.table_name 
    AND table_schema = 'public'
  ) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_name LIKE '%stripe%'
ORDER BY table_name;

-- 12. Final recommendation based on findings
SELECT 
  'NEXT STEPS:' as recommendation,
  CASE 
    WHEN EXISTS (SELECT 1 FROM auth.users WHERE email ILIKE '%memo%' OR email ILIKE '%gsalinas%') 
    THEN 'Found similar users - check results above for correct email'
    
    WHEN EXISTS (SELECT 1 FROM stripe_customers WHERE email ILIKE '%memo%' OR email ILIKE '%gsalinas%')
    THEN 'User exists in stripe_customers but not auth.users - need to create auth user'
    
    WHEN EXISTS (SELECT 1 FROM stripe_orders WHERE email ILIKE '%memo%' OR email ILIKE '%gsalinas%')
    THEN 'User has orders but no customer/auth record - need full recovery'
    
    ELSE 'User completely missing - check Stripe dashboard directly for this customer'
  END as action_needed; 