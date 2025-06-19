-- Fix dashboard view and ensure kendranespiritu@gmail.com subscription shows up
-- The issue is that the view filters by payment_type='monthly' but the customer record may not have this set

-- First, let's see what's in the customer record for kendranespiritu
SELECT 'CURRENT CUSTOMER DATA:' as info, user_id, customer_id, email, payment_type, beta_user, deleted_at
FROM stripe_customers 
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
   OR email = 'kendranespiritu@gmail.com';

-- Update the customer record to ensure payment_type is set correctly
UPDATE stripe_customers 
SET payment_type = 'monthly'
WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
  AND payment_type IS NULL;

-- Also check if the subscription record exists and is correct
SELECT 'SUBSCRIPTION AFTER RECOVERY:' as info, customer_id, subscription_id, status, price_id, deleted_at
FROM stripe_subscriptions
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
);

-- Fix the view to be more inclusive - show all subscriptions, not just monthly
-- The original view was too restrictive
DROP VIEW IF EXISTS stripe_user_subscriptions;
CREATE VIEW stripe_user_subscriptions WITH (security_invoker = true) AS
SELECT
    c.customer_id,
    s.subscription_id,
    s.status as subscription_status,
    s.price_id,
    s.current_period_start,
    s.current_period_end,
    s.cancel_at_period_end,
    s.payment_method_brand,
    s.payment_method_last4,
    c.beta_user,
    c.payment_type
FROM stripe_customers c
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
WHERE c.user_id = auth.uid()
  AND c.deleted_at IS NULL
  AND (s.deleted_at IS NULL OR s.id IS NULL); -- Show customers even if no subscription yet

GRANT SELECT ON stripe_user_subscriptions TO authenticated;

-- Test the view for kendranespiritu specifically
SELECT 'VIEW TEST FOR KENDRANESPIRITU:' as info, *
FROM stripe_user_subscriptions
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'kendranespiritu@gmail.com')
);

-- Also ensure the customer has the correct payment_type for their subscription
UPDATE stripe_customers c
SET payment_type = CASE 
  WHEN s.price_id = 'price_1RW02UInTpoMSXouhnQLA7Jn' THEN 'lifetime'
  WHEN s.price_id = 'price_1RW01zInTpoMSXoua1wZb9zY' THEN 'monthly'
  ELSE c.payment_type
END
FROM stripe_subscriptions s
WHERE c.customer_id = s.customer_id
  AND c.deleted_at IS NULL
  AND s.deleted_at IS NULL
  AND c.payment_type IS NULL;
