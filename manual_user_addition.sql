-- Manual User Addition Script
-- Use this to add users who paid outside the website system
-- 
-- INSTRUCTIONS:
-- 1. Replace the variables below with the actual user information
-- 2. Run this script in your Supabase SQL editor
-- 3. The user should then show as having an active subscription

-- ===== USER INFORMATION TO REPLACE =====
-- Replace these values with the actual user data:

DO $$
DECLARE
  -- ===== REPLACE THESE VALUES =====
  user_email text := 'val.powell715@gmail.com';  -- User's email address
  purchase_type text := 'lifetime';               -- 'lifetime' or 'monthly' 
  amount_paid numeric := 99.99;                   -- Amount they actually paid
  -- ===== END REPLACE SECTION =====
  
  -- GENERATED VALUES (don't modify these):
  target_user_id uuid;
  target_customer_id text;
  generated_payment_intent text;
  generated_checkout_session text;
  price_id_to_use text;
  amount_in_cents integer;
BEGIN
  
  RAISE NOTICE '🚀 Starting manual user addition for: %', user_email;
  
  -- Step 1: Find the user in auth.users
  SELECT id INTO target_user_id
  FROM auth.users 
  WHERE email = user_email;
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION '❌ User with email % not found in auth.users. They need to create an account first!', user_email;
  END IF;
  
  RAISE NOTICE '✅ Found user ID: %', target_user_id;
  
  -- Step 2: Generate unique identifiers
  target_customer_id := 'cus_manual_' || SUBSTRING(MD5(user_email || NOW()::text) FROM 1 FOR 14);
  generated_payment_intent := 'pi_manual_' || SUBSTRING(MD5(user_email || NOW()::text) FROM 1 FOR 24);
  generated_checkout_session := 'cs_manual_' || SUBSTRING(MD5(user_email || NOW()::text) FROM 1 FOR 24);
  
  -- Step 3: Set price_id and amount based on purchase type
  IF purchase_type = 'lifetime' THEN
    price_id_to_use := 'price_1RbnH2InTpoMSXou7m5p43Sh'; -- Your lifetime price ID
  ELSIF purchase_type = 'yearly' THEN
    price_id_to_use := 'price_1RbnIfInTpoMSXouPdJBHz97'; -- Your yearly price ID  
  ELSE
    price_id_to_use := 'price_1RW01zInTpoMSXoua1wZb9zY'; -- Your monthly price ID
  END IF;
  
  amount_in_cents := (amount_paid * 100)::integer;
  
  RAISE NOTICE '📋 Generated customer ID: %', target_customer_id;
  RAISE NOTICE '💳 Payment intent: %', generated_payment_intent;
  RAISE NOTICE '💰 Amount: $% (% cents)', amount_paid, amount_in_cents;
  
  -- Step 4: Create stripe_customers record
  INSERT INTO stripe_customers (
    user_id,
    customer_id,
    email,
    payment_type,
    subscription_status,
    beta_user,
    created_at,
    updated_at
  ) VALUES (
    target_user_id,
    target_customer_id,
    user_email,
    purchase_type,
    'active',
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    email = EXCLUDED.email,
    payment_type = EXCLUDED.payment_type,
    subscription_status = 'active',
    beta_user = true,
    updated_at = NOW(),
    deleted_at = NULL; -- Ensure not soft-deleted
    
  RAISE NOTICE '✅ Created/updated stripe_customers record';
  
  -- Step 5: Create stripe_orders record
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
    -- Subscription fields for monthly users
    subscription_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end,
    subscription_status,
    created_at,
    updated_at
  ) VALUES (
    generated_checkout_session,
    generated_payment_intent,
    target_customer_id,
    user_email,
    amount_in_cents,
    amount_in_cents,
    'usd',
    'paid',
    'completed',
    purchase_type,
    price_id_to_use,
    'card', -- Default payment method
    '****', -- Placeholder for card last 4
    -- Subscription data (NULL for lifetime, generated for monthly/yearly)
    CASE WHEN purchase_type = 'lifetime' THEN NULL 
         ELSE 'sub_manual_' || SUBSTRING(MD5(target_customer_id) FROM 1 FOR 24) END,
    CASE WHEN purchase_type = 'lifetime' THEN NULL 
         ELSE EXTRACT(EPOCH FROM NOW())::bigint END,
    CASE WHEN purchase_type = 'lifetime' THEN NULL 
         WHEN purchase_type = 'yearly' THEN EXTRACT(EPOCH FROM NOW() + INTERVAL '1 year')::bigint
         ELSE EXTRACT(EPOCH FROM NOW() + INTERVAL '1 month')::bigint END,
    CASE WHEN purchase_type = 'lifetime' THEN false ELSE false END,
    CASE WHEN purchase_type = 'lifetime' THEN NULL ELSE 'active' END,
    NOW(),
    NOW()
  )
  ON CONFLICT (payment_intent_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    status = 'completed',
    payment_status = 'paid',
    updated_at = NOW();
    
  RAISE NOTICE '✅ Created/updated stripe_orders record';
  
  -- Step 6: Log the manual addition
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    target_customer_id,
    'manual_user_addition',
    'completed',
    jsonb_build_object(
      'email', user_email,
      'purchase_type', purchase_type,
      'amount_paid', amount_paid,
      'added_by', 'admin_manual_script',
      'reason', 'user_paid_outside_website',
      'timestamp', NOW()
    )
  );
  
  RAISE NOTICE '✅ Logged manual addition';
  
  -- Step 7: Verify the addition worked
  RAISE NOTICE '🔍 Verification Results:';
  
  -- Check stripe_customers
  IF EXISTS (SELECT 1 FROM stripe_customers WHERE user_id = target_user_id AND subscription_status = 'active') THEN
    RAISE NOTICE '✅ stripe_customers: User shows as active';
  ELSE
    RAISE NOTICE '❌ stripe_customers: User NOT showing as active';
  END IF;
  
  -- Check stripe_orders  
  IF EXISTS (SELECT 1 FROM stripe_orders WHERE customer_id = target_customer_id AND status = 'completed') THEN
    RAISE NOTICE '✅ stripe_orders: Order shows as completed';
  ELSE
    RAISE NOTICE '❌ stripe_orders: Order NOT showing as completed';
  END IF;
  
  RAISE NOTICE '🎉 Manual user addition completed for: %', user_email;
  RAISE NOTICE '📧 User should now see active subscription in their dashboard';
  
END $$; 