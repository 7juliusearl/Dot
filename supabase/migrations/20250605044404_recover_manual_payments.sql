-- Recovery script for manual payment links that weren't properly connected to user accounts
-- This helps identify and fix payments that went to Stripe but weren't linked to users

-- Create a function to help manually connect payments to users
CREATE OR REPLACE FUNCTION recover_manual_payment(
  user_email TEXT,
  stripe_customer_id TEXT DEFAULT NULL,
  stripe_payment_intent_id TEXT DEFAULT NULL,
  purchase_type TEXT DEFAULT 'lifetime'
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_user_id UUID;
  target_customer_id TEXT;
  existing_customer RECORD;
  result_message TEXT;
BEGIN
  -- Find the user by email
  SELECT id INTO target_user_id
  FROM auth.users
  WHERE email = user_email;
  
  IF target_user_id IS NULL THEN
    RETURN 'ERROR: User not found with email ' || user_email;
  END IF;
  
  -- Check if user already has a customer record
  SELECT * INTO existing_customer
  FROM stripe_customers
  WHERE user_id = target_user_id AND deleted_at IS NULL;
  
  IF existing_customer.customer_id IS NOT NULL THEN
    target_customer_id := existing_customer.customer_id;
    result_message := 'User already has customer record: ' || target_customer_id;
  ELSE
    -- If stripe_customer_id provided, create the mapping
    IF stripe_customer_id IS NOT NULL THEN
      INSERT INTO stripe_customers (user_id, customer_id, email)
      VALUES (target_user_id, stripe_customer_id, user_email)
      ON CONFLICT (user_id) DO UPDATE SET
        customer_id = EXCLUDED.customer_id,
        email = EXCLUDED.email,
        deleted_at = NULL,
        updated_at = NOW();
      
      target_customer_id := stripe_customer_id;
      result_message := 'Created customer mapping: ' || stripe_customer_id;
    ELSE
      RETURN 'ERROR: No existing customer record and no stripe_customer_id provided';
    END IF;
  END IF;
  
  -- If payment_intent_id provided, create order record
  IF stripe_payment_intent_id IS NOT NULL THEN
    INSERT INTO stripe_orders (
      customer_id,
      payment_intent_id,
      status,
      purchase_type,
      email,
      amount_total,
      currency,
      payment_status
    ) VALUES (
      target_customer_id,
      stripe_payment_intent_id,
      'completed',
      purchase_type,
      user_email,
      CASE WHEN purchase_type = 'lifetime' THEN 4999 ELSE 999 END, -- Default amounts
      'usd',
      'paid'
    )
    ON CONFLICT (payment_intent_id) DO UPDATE SET
      customer_id = EXCLUDED.customer_id,
      status = 'completed',
      updated_at = NOW();
    
    result_message := result_message || ' | Created order record: ' || stripe_payment_intent_id;
  END IF;
  
  -- Create/update subscription record for the user
  INSERT INTO stripe_subscriptions (
    customer_id,
    status,
    price_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end
  ) VALUES (
    target_customer_id,
    'active',
    CASE WHEN purchase_type = 'lifetime' THEN 'price_1RW02UInTpoMSXouhnQLA7Jn' ELSE 'price_1RW01zInTpoMSXoua1wZb9zY' END,
    EXTRACT(EPOCH FROM NOW())::bigint,
    CASE WHEN purchase_type = 'monthly' THEN EXTRACT(EPOCH FROM NOW() + INTERVAL '1 month')::bigint ELSE NULL END,
    false
  )
  ON CONFLICT (customer_id) DO UPDATE SET
    status = 'active',
    price_id = EXCLUDED.price_id,
    current_period_start = EXCLUDED.current_period_start,
    current_period_end = EXCLUDED.current_period_end,
    updated_at = NOW();
  
  result_message := result_message || ' | Updated subscription status to active';
  
  -- Log the recovery action
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    target_customer_id,
    'manual_payment_recovery',
    'success',
    jsonb_build_object(
      'user_email', user_email,
      'user_id', target_user_id,
      'stripe_customer_id', stripe_customer_id,
      'payment_intent_id', stripe_payment_intent_id,
      'purchase_type', purchase_type,
      'recovery_timestamp', NOW()
    )
  );
  
  RETURN result_message;
END;
$$;

-- Create a view to help identify users who might need manual recovery
CREATE OR REPLACE VIEW potential_manual_payment_users AS
SELECT 
  u.id as user_id,
  u.email,
  u.created_at as user_created_at,
  sc.customer_id,
  sc.created_at as customer_created_at,
  so.status as order_status,
  so.purchase_type,
  so.payment_intent_id,
  ss.status as subscription_status,
  CASE 
    WHEN sc.customer_id IS NULL THEN 'No customer record'
    WHEN so.status IS NULL THEN 'No completed orders'
    WHEN ss.status IS NULL OR ss.status = 'not_started' THEN 'No active subscription'
    ELSE 'Appears complete'
  END as recovery_needed
FROM auth.users u
LEFT JOIN stripe_customers sc ON u.id = sc.user_id AND sc.deleted_at IS NULL
LEFT JOIN stripe_orders so ON sc.customer_id = so.customer_id AND so.status = 'completed' AND so.deleted_at IS NULL
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id AND ss.deleted_at IS NULL
WHERE u.created_at > '2024-01-01' -- Adjust date as needed
ORDER BY u.created_at DESC;

-- Add helpful comments for usage
COMMENT ON FUNCTION recover_manual_payment IS 'Use this function to manually connect payments to user accounts. Example: SELECT recover_manual_payment(''user@example.com'', ''cus_stripe_id'', ''pi_payment_intent'', ''lifetime'');';

COMMENT ON VIEW potential_manual_payment_users IS 'Shows users who might need manual payment recovery. Focus on users with ''No completed orders'' or ''No active subscription'' status.';
