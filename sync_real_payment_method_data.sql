/*
  # Sync Real Payment Method Data from Stripe
  
  This creates a function that can be called by your webhook handlers
  or manually to fetch real payment method data from Stripe and update
  the database with actual card digits instead of fake data.
*/

CREATE OR REPLACE FUNCTION sync_payment_method_from_stripe(
  p_customer_id text,
  p_payment_intent_id text DEFAULT NULL,
  p_subscription_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stripe_secret_key text;
  payment_method_data jsonb;
  result jsonb;
BEGIN
  -- This function should be called from your Supabase Edge Functions
  -- where you have access to Stripe API
  
  -- For now, this function logs the request and returns instructions
  -- for manual implementation in your webhook handlers
  
  INSERT INTO sync_logs (
    customer_id,
    operation,
    status,
    details
  ) VALUES (
    p_customer_id,
    'payment_method_sync_request',
    'pending',
    jsonb_build_object(
      'payment_intent_id', p_payment_intent_id,
      'subscription_id', p_subscription_id,
      'timestamp', NOW(),
      'instructions', 'Implement this sync in webhook handlers using Stripe API'
    )
  );
  
  result := jsonb_build_object(
    'status', 'logged',
    'message', 'Payment method sync request logged. Implement in webhook handlers.',
    'customer_id', p_customer_id,
    'payment_intent_id', p_payment_intent_id,
    'subscription_id', p_subscription_id
  );
  
  RETURN result;
END;
$$;

-- Create a query to identify users who need payment method sync
CREATE OR REPLACE VIEW users_needing_payment_method_sync AS
SELECT 
  sc.customer_id,
  sc.email,
  sc.user_id,
  so.payment_intent_id,
  so.purchase_type,
  so.payment_method_last4,
  so.payment_method_brand,
  CASE 
    WHEN so.payment_method_last4 ~ '^[0-9]{4}$' THEN 'Has real card data'
    WHEN so.payment_method_last4 = '****' THEN 'Needs sync from Stripe'
    ELSE 'Has fake data - needs cleanup and sync'
  END as sync_status,
  so.created_at as order_date
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE so.status = 'completed'
  AND so.deleted_at IS NULL
  AND (
    so.payment_method_last4 = '****' 
    OR so.payment_method_last4 !~ '^[0-9]{4}$'
  )
ORDER BY so.created_at DESC;

-- Show users needing sync
SELECT 
  'Users needing payment method sync:' as info;

SELECT * FROM users_needing_payment_method_sync LIMIT 20;

-- Manual update function for when you get real data from Stripe
CREATE OR REPLACE FUNCTION update_payment_method_data(
  p_customer_id text,
  p_payment_method_brand text,
  p_payment_method_last4 text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  orders_updated integer;
  subscriptions_updated integer;
BEGIN
  -- Validate that last4 is actually 4 digits
  IF p_payment_method_last4 !~ '^[0-9]{4}$' THEN
    RAISE EXCEPTION 'payment_method_last4 must be exactly 4 digits, got: %', p_payment_method_last4;
  END IF;
  
  -- Update stripe_orders
  UPDATE stripe_orders
  SET 
    payment_method_brand = p_payment_method_brand,
    payment_method_last4 = p_payment_method_last4,
    updated_at = NOW()
  WHERE customer_id = p_customer_id
    AND status = 'completed'
    AND deleted_at IS NULL;
    
  GET DIAGNOSTICS orders_updated = ROW_COUNT;
  
  -- Update stripe_subscriptions
  UPDATE stripe_subscriptions
  SET 
    payment_method_brand = p_payment_method_brand,
    payment_method_last4 = p_payment_method_last4,
    updated_at = NOW()
  WHERE customer_id = p_customer_id
    AND deleted_at IS NULL;
    
  GET DIAGNOSTICS subscriptions_updated = ROW_COUNT;
  
  -- Log the update
  INSERT INTO sync_logs (
    customer_id,
    operation,
    status,
    details
  ) VALUES (
    p_customer_id,
    'payment_method_manual_update',
    'completed',
    jsonb_build_object(
      'payment_method_brand', p_payment_method_brand,
      'payment_method_last4', p_payment_method_last4,
      'orders_updated', orders_updated,
      'subscriptions_updated', subscriptions_updated,
      'timestamp', NOW()
    )
  );
  
  result := jsonb_build_object(
    'status', 'success',
    'customer_id', p_customer_id,
    'orders_updated', orders_updated,
    'subscriptions_updated', subscriptions_updated,
    'payment_method_brand', p_payment_method_brand,
    'payment_method_last4', p_payment_method_last4
  );
  
  RETURN result;
END;
$$;

-- Example of how to use the manual update function:
-- SELECT update_payment_method_data('cus_example123', 'visa', '4242');

-- Create a summary of the payment method data issue
SELECT 
  'PAYMENT METHOD DATA ISSUE SUMMARY' as summary_type,
  COUNT(*) as total_completed_orders,
  COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) as orders_with_real_card_data,
  COUNT(CASE WHEN payment_method_last4 = '****' THEN 1 END) as orders_with_placeholder,
  COUNT(CASE WHEN payment_method_last4 !~ '^[0-9]{4}$' AND payment_method_last4 != '****' THEN 1 END) as orders_with_fake_data,
  ROUND(
    (COUNT(CASE WHEN payment_method_last4 ~ '^[0-9]{4}$' THEN 1 END) * 100.0 / COUNT(*)), 2
  ) as percentage_with_real_data
FROM stripe_orders 
WHERE status = 'completed' AND deleted_at IS NULL; 