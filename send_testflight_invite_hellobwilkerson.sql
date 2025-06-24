-- Manual TestFlight invite function for hellobwilkerson@gmail.com
-- Run this after fixing their database records

-- First, let's create a function to manually send TestFlight invites
CREATE OR REPLACE FUNCTION send_manual_testflight_invite(user_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  customer_record record;
  order_record record;
BEGIN
  -- Check if user exists and has valid subscription
  SELECT 
    sc.customer_id,
    sc.email,
    sc.payment_type,
    sc.beta_user,
    sc.user_id
  INTO customer_record
  FROM stripe_customers sc
  WHERE LOWER(sc.email) = LOWER(user_email)
    AND sc.deleted_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'message', 'User not found in stripe_customers table',
      'email', user_email
    );
  END IF;

  -- Check if user has a completed order
  SELECT 
    so.status,
    so.purchase_type,
    so.subscription_status,
    so.amount_total
  INTO order_record
  FROM stripe_orders so
  WHERE so.customer_id = customer_record.customer_id
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  ORDER BY so.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'message', 'No completed orders found for user',
      'email', user_email,
      'customer_id', customer_record.customer_id
    );
  END IF;

  -- Check if user should have access based on purchase type
  IF order_record.purchase_type = 'lifetime' AND order_record.subscription_status IS NULL THEN
    -- User should have access, return success
    result := jsonb_build_object(
      'status', 'success',
      'message', 'User has valid lifetime access',
      'email', customer_record.email,
      'customer_id', customer_record.customer_id,
      'purchase_type', order_record.purchase_type,
      'amount_paid', order_record.amount_total / 100.0,
      'testflight_link', 'https://testflight.apple.com/join/cGYTUPH1',
      'action_needed', 'Have user log out and log back in, then try TestFlight access again'
    );
  ELSE
    result := jsonb_build_object(
      'status', 'error',
      'message', 'User does not have valid access',
      'purchase_type', order_record.purchase_type,
      'subscription_status', order_record.subscription_status,
      'email', customer_record.email
    );
  END IF;

  -- Log the manual invite attempt
  INSERT INTO sync_logs (customer_id, operation, status, details)
  VALUES (
    customer_record.customer_id,
    'manual_testflight_invite',
    CASE WHEN result->>'status' = 'success' THEN 'completed' ELSE 'failed' END,
    result
  );

  RETURN result;
END;
$$;

-- Now call the function for hellobwilkerson@gmail.com
SELECT send_manual_testflight_invite('hellobwilkerson@gmail.com') as result;

-- Alternative: Direct TestFlight link query
SELECT 
  'TestFlight Access Check:' as info,
  sc.email,
  sc.payment_type,
  so.purchase_type,
  so.subscription_status,
  so.amount_total / 100.0 as amount_paid,
  CASE 
    WHEN so.purchase_type = 'lifetime' AND so.subscription_status IS NULL 
      THEN 'https://testflight.apple.com/join/cGYTUPH1'
    WHEN so.purchase_type = 'lifetime' AND so.subscription_status = 'canceled'
      THEN 'ACCESS DENIED - Lifetime canceled'
    ELSE 'ACCESS DENIED - Invalid subscription'
  END as testflight_status
FROM stripe_customers sc
JOIN stripe_orders so ON sc.customer_id = so.customer_id
WHERE LOWER(sc.email) = 'hellobwilkerson@gmail.com'
  AND so.status = 'completed'
  AND so.deleted_at IS NULL
  AND sc.deleted_at IS NULL
ORDER BY so.created_at DESC
LIMIT 1; 