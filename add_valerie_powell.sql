-- Add Valerie Powell using actual Stripe data
-- Customer ID: cus_SRMhEVoun8SRJE
-- Payment: $27.99 (LIFETIME ACCESS at old pricing)
-- Payment Intent: pi_3RWTyXInTpoMSXou2urGyCmd
-- Date: June 4, 2024

DO $$
DECLARE
  target_user_id uuid;
  stripe_customer_id text := 'cus_SRMhEVoun8SRJE';
  user_email text := 'val.powell715@gmail.com';
  stripe_payment_intent text := 'pi_3RWTyXInTpoMSXou2urGyCmd';
  generated_checkout_session text;
  lifetime_price_id text := 'price_1RbnH2InTpoMSXou7m5p43Sh'; -- Your lifetime price ID
BEGIN
  
  RAISE NOTICE '🚀 Adding Valerie Powell with actual Stripe data';
  RAISE NOTICE '📧 Email: %', user_email;
  RAISE NOTICE '🏷️ Customer ID: %', stripe_customer_id;
  RAISE NOTICE '💳 Payment Intent: %', stripe_payment_intent;
  RAISE NOTICE '💰 Amount: $27.99 (LIFETIME ACCESS at old pricing)';
  
  -- Step 1: Find the user in auth.users
  SELECT id INTO target_user_id
  FROM auth.users 
  WHERE email = user_email;
  
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION '❌ User with email % not found in auth.users. They need to create an account first!', user_email;
  END IF;
  
  RAISE NOTICE '✅ Found user ID: %', target_user_id;
  
  -- Generate checkout session ID (since we don't have it from Stripe)
  generated_checkout_session := 'cs_manual_' || SUBSTRING(MD5(stripe_customer_id || stripe_payment_intent) FROM 1 FOR 24);
  
  -- Step 2: Create stripe_customers record
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
    stripe_customer_id,
    user_email,
    'lifetime', -- $27.99 was old lifetime pricing
    true,
    '2024-06-04 19:56:00'::timestamp, -- Approximate time from screenshot
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    customer_id = EXCLUDED.customer_id,
    email = EXCLUDED.email,
    payment_type = 'lifetime',
    beta_user = true,
    updated_at = NOW(),
    deleted_at = NULL;
    
  RAISE NOTICE '✅ Created/updated stripe_customers record';
  
  -- Step 3: Create stripe_orders record with actual Stripe data
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
    -- Subscription fields for yearly user
    subscription_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end,
    subscription_status,
    created_at,
    updated_at
  ) VALUES (
    generated_checkout_session,
    stripe_payment_intent,
    stripe_customer_id,
    user_email,
    2799, -- $27.99 in cents
    2799,
    'usd',
    'paid',
    'completed',
    'lifetime', -- Lifetime access at old pricing
    lifetime_price_id,
    'card',
    '****',
    -- Lifetime users don't have subscription data
    NULL, -- No subscription_id for lifetime
    NULL, -- No period start for lifetime
    NULL, -- No period end for lifetime
    false,
    NULL, -- No subscription status for lifetime
    '2024-06-04 19:56:00'::timestamp,
    NOW()
  );
    
  RAISE NOTICE '✅ Created/updated stripe_orders record';
  
  -- Step 4: Log the manual addition
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    stripe_customer_id,
    'manual_user_addition_with_stripe_data',
    'completed',
    jsonb_build_object(
      'email', user_email,
      'stripe_customer_id', stripe_customer_id,
      'payment_intent_id', stripe_payment_intent,
      'purchase_type', 'lifetime_access_old_pricing',
      'amount_paid', 27.99,
      'added_by', 'admin_manual_script',
      'reason', 'user_paid_in_stripe_but_missing_from_database',
      'stripe_payment_date', '2024-06-04',
      'timestamp', NOW()
    )
  );
  
  RAISE NOTICE '✅ Logged manual addition';
  
  -- Step 5: Verify the addition worked
  RAISE NOTICE '🔍 Verification Results:';
  
  -- Check stripe_customers
  IF EXISTS (SELECT 1 FROM stripe_customers WHERE user_id = target_user_id AND customer_id = stripe_customer_id) THEN
    RAISE NOTICE '✅ stripe_customers: User added successfully';
  ELSE
    RAISE NOTICE '❌ stripe_customers: User NOT found';
  END IF;
  
  -- Check stripe_orders  
  IF EXISTS (SELECT 1 FROM stripe_orders WHERE customer_id = stripe_customer_id AND status = 'completed') THEN
    RAISE NOTICE '✅ stripe_orders: Order shows as completed';
  ELSE
    RAISE NOTICE '❌ stripe_orders: Order NOT showing as completed';
  END IF;
  
  RAISE NOTICE '🎉 Manual user addition completed for Valerie Powell';
  RAISE NOTICE '📧 User should now see active LIFETIME access in their dashboard';
  RAISE NOTICE '🎯 Grandfathered at old pricing: $27.99 for lifetime access';
  
END $$; 