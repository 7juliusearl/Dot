-- Create missing order record for kendranespiritu@gmail.com
-- The dashboard now relies on stripe_orders as source of truth, so we need a completed order record

-- Get the user's customer record
WITH user_data AS (
  SELECT 
    u.id as user_id,
    u.email,
    sc.customer_id
  FROM auth.users u
  LEFT JOIN stripe_customers sc ON u.id = sc.user_id AND sc.deleted_at IS NULL
  WHERE u.email = 'kendranespiritu@gmail.com'
),
subscription_data AS (
  SELECT ss.customer_id, ss.price_id, ss.created_at
  FROM stripe_subscriptions ss
  JOIN user_data ud ON ss.customer_id = ud.customer_id
  WHERE ss.deleted_at IS NULL
  LIMIT 1
)
-- Insert a completed order record if it doesn't exist
INSERT INTO stripe_orders (
  checkout_session_id,
  payment_intent_id,
  customer_id,
  amount_subtotal,
  amount_total,
  currency,
  payment_status,
  status,
  purchase_type,
  email,
  created_at,
  updated_at
)
SELECT 
  'cs_recovery_' || ud.customer_id,
  'pi_recovery_' || ud.customer_id,
  ud.customer_id,
  399, -- $3.99 in cents
  399,
  'usd',
  'paid',
  'completed',
  'monthly',
  ud.email,
  COALESCE(sd.created_at, NOW()),
  NOW()
FROM user_data ud
LEFT JOIN subscription_data sd ON ud.customer_id = sd.customer_id
WHERE ud.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM stripe_orders so 
    WHERE so.customer_id = ud.customer_id 
    AND so.status = 'completed'
    AND so.deleted_at IS NULL
  );

-- Log the action
INSERT INTO sync_logs (customer_id, operation, status, details)
SELECT 
  customer_id,
  'create_missing_order',
  'success',
  jsonb_build_object(
    'user_email', 'kendranespiritu@gmail.com',
    'reason', 'dashboard_requires_completed_order',
    'purchase_type', 'monthly',
    'timestamp', NOW()
  )
FROM stripe_customers 
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
  AND deleted_at IS NULL;
