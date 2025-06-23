/*
  # Add yearly purchase type support
  
  1. Changes
    - Modify purchase_type CHECK constraint to include 'yearly'
    - Update existing yearly orders to use proper purchase_type
    - Update webhook logic to handle yearly subscriptions
  
  2. Security
    - Maintains existing RLS policies
*/

-- Step 1: Drop the existing CHECK constraint
ALTER TABLE stripe_orders 
DROP CONSTRAINT IF EXISTS stripe_orders_purchase_type_check;

-- Step 2: Add new CHECK constraint with yearly support
ALTER TABLE stripe_orders 
ADD CONSTRAINT stripe_orders_purchase_type_check 
CHECK (purchase_type IN ('lifetime', 'monthly', 'yearly'));

-- Step 3: Update existing orders that should be yearly
-- (Orders with 1-year periods but marked as monthly)
UPDATE stripe_orders 
SET 
  purchase_type = 'yearly',
  updated_at = NOW()
WHERE purchase_type = 'monthly'
  AND current_period_end IS NOT NULL
  AND current_period_start IS NOT NULL
  AND (current_period_end - current_period_start) > (11 * 30 * 24 * 60 * 60) -- More than 11 months
  AND status = 'completed'
  AND deleted_at IS NULL;

-- Step 4: Update price mapping for yearly subscriptions
-- Set correct price_id for yearly orders
UPDATE stripe_orders 
SET 
  price_id = 'price_1RbnIfInTpoMSXouPdJBHz97', -- Your yearly price ID
  updated_at = NOW()
WHERE purchase_type = 'yearly'
  AND (price_id IS NULL OR price_id = 'price_1RW01zInTpoMSXoua1wZb9zY')
  AND status = 'completed'
  AND deleted_at IS NULL;

-- Step 5: Update the view to handle yearly subscriptions
DROP VIEW IF EXISTS stripe_user_orders;
CREATE VIEW stripe_user_orders WITH (security_invoker = true) AS
SELECT
    c.customer_id,
    o.id as order_id,
    o.checkout_session_id,
    o.payment_intent_id,
    o.amount_subtotal,
    o.amount_total,
    o.currency,
    o.payment_status,
    o.status as order_status,
    o.created_at as order_date,
    o.purchase_type,
    CASE 
      WHEN o.purchase_type = 'lifetime' THEN 'Lifetime Access'
      WHEN o.purchase_type = 'yearly' THEN 'Yearly Subscription'
      WHEN o.purchase_type = 'monthly' THEN 'Monthly Subscription'
      ELSE o.purchase_type
    END as purchase_type_display
FROM stripe_customers c
LEFT JOIN stripe_orders o ON c.customer_id = o.customer_id
WHERE c.user_id = auth.uid()
AND c.deleted_at IS NULL
AND o.deleted_at IS NULL;

-- Step 6: Log the migration
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'add_yearly_purchase_type',
  'completed',
  jsonb_build_object(
    'action', 'added_yearly_to_purchase_type_constraint',
    'timestamp', NOW(),
    'yearly_orders_updated', (
      SELECT COUNT(*) 
      FROM stripe_orders 
      WHERE purchase_type = 'yearly'
      AND updated_at > NOW() - INTERVAL '5 minutes'
    )
  )
);

-- Step 7: Verify the changes
DO $$
DECLARE
  yearly_count INTEGER;
  monthly_count INTEGER;
  lifetime_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO yearly_count FROM stripe_orders WHERE purchase_type = 'yearly' AND deleted_at IS NULL;
  SELECT COUNT(*) INTO monthly_count FROM stripe_orders WHERE purchase_type = 'monthly' AND deleted_at IS NULL;
  SELECT COUNT(*) INTO lifetime_count FROM stripe_orders WHERE purchase_type = 'lifetime' AND deleted_at IS NULL;
  
  RAISE NOTICE 'Migration completed:';
  RAISE NOTICE '- Yearly orders: %', yearly_count;
  RAISE NOTICE '- Monthly orders: %', monthly_count;
  RAISE NOTICE '- Lifetime orders: %', lifetime_count;
END $$; 