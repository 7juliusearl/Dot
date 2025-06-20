-- Search and Fix User Script for val.powell715@gmail.com
-- Run these queries one by one to diagnose and fix the issue

-- ===== STEP 1: SEARCH FOR THE USER =====
-- Check if user exists in auth.users
SELECT 'AUTH USERS CHECK:' as step;
SELECT 
  id as user_id,
  email,
  created_at,
  email_confirmed_at
FROM auth.users 
WHERE email = 'val.powell715@gmail.com';

-- ===== STEP 2: CHECK STRIPE CUSTOMERS =====
SELECT 'STRIPE CUSTOMERS CHECK:' as step;
SELECT 
  customer_id,
  user_id,
  email,
  payment_type,
  beta_user,
  created_at,
  deleted_at
FROM stripe_customers 
WHERE email = 'val.powell715@gmail.com' 
   OR user_id IN (SELECT id FROM auth.users WHERE email = 'val.powell715@gmail.com');

-- ===== STEP 3: CHECK STRIPE ORDERS =====
SELECT 'STRIPE ORDERS CHECK:' as step;
SELECT 
  id,
  customer_id,
  email,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  payment_status,
  status,
  created_at,
  deleted_at
FROM stripe_orders 
WHERE email = 'val.powell715@gmail.com'
   OR customer_id IN (
     SELECT customer_id FROM stripe_customers 
     WHERE email = 'val.powell715@gmail.com'
   );

-- ===== STEP 4: CHECK FOR SIMILAR EMAILS =====
SELECT 'SIMILAR EMAILS CHECK:' as step;
SELECT 
  email,
  customer_id,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  status,
  created_at
FROM stripe_orders 
WHERE email ILIKE '%val%' 
   OR email ILIKE '%powell%'
ORDER BY created_at DESC;

-- ===== STEP 5: RECENT ORDERS (LAST 30 DAYS) =====
SELECT 'RECENT ORDERS (LAST 30 DAYS):' as step;
SELECT 
  email,
  customer_id,
  purchase_type,
  amount_total / 100.0 as amount_dollars,
  payment_status,
  status,
  created_at
FROM stripe_orders 
WHERE created_at > NOW() - INTERVAL '30 days'
  AND status = 'completed'
ORDER BY created_at DESC
LIMIT 20;

-- ===== STEP 6: IF USER EXISTS BUT NO PAYMENT RECORD =====
-- Run this if the user exists in auth.users but has no payment records
-- This will manually create the records they need

/*
-- UNCOMMENT AND RUN THIS SECTION IF NEEDED:

DO $$
DECLARE
  target_user_id uuid;
  target_customer_id text;
  generated_payment_intent text;
  generated_checkout_session text;
BEGIN
  -- Get user ID
  SELECT id INTO target_user_id
  FROM auth.users 
  WHERE email = 'val.powell715@gmail.com';
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found in auth.users';
  END IF;
  
  -- Generate IDs
  target_customer_id := 'cus_manual_' || SUBSTRING(MD5('val.powell715@gmail.com' || NOW()::text) FROM 1 FOR 14);
  generated_payment_intent := 'pi_manual_' || SUBSTRING(MD5('val.powell715@gmail.com' || NOW()::text) FROM 1 FOR 24);
  generated_checkout_session := 'cs_manual_' || SUBSTRING(MD5('val.powell715@gmail.com' || NOW()::text) FROM 1 FOR 24);
  
  -- Create stripe_customers record
  INSERT INTO stripe_customers (
    user_id,
    customer_id,
    email,
    payment_type,
    beta_user,
    created_at,
    updated_at
  ) VALUES (
    target_user_id,
    target_customer_id,
    'val.powell715@gmail.com',
    'lifetime',
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    email = EXCLUDED.email,
    payment_type = 'lifetime',
    beta_user = true,
    updated_at = NOW(),
    deleted_at = NULL;
    
  -- Create stripe_orders record
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
    payment_method_brand,
    payment_method_last4,
    created_at,
    updated_at
  ) VALUES (
    generated_checkout_session,
    generated_payment_intent,
    target_customer_id,
    'val.powell715@gmail.com',
    9999, -- $99.99 in cents
    9999,
    'usd',
    'paid',
    'completed',
    'lifetime',
    'price_1RbnH2InTpoMSXou7m5p43Sh',
    'card',
    '****',
    NOW(),
    NOW()
  )
  ON CONFLICT (payment_intent_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    status = 'completed',
    payment_status = 'paid',
    updated_at = NOW();
    
  RAISE NOTICE 'Successfully created records for val.powell715@gmail.com';
  
END $$;

*/

-- ===== STEP 7: VERIFY THE FIX =====
-- Run this after the manual creation to verify it worked
SELECT 'VERIFICATION - FINAL CHECK:' as step;
SELECT 
  sc.email,
  sc.payment_type,
  sc.beta_user,
  so.purchase_type,
  so.amount_total / 100.0 as amount_dollars,
  so.status as order_status
FROM stripe_customers sc
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE sc.email = 'val.powell715@gmail.com'; 