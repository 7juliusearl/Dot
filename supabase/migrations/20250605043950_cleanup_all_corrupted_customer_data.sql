-- Clean up ALL corrupted customer data from incomplete payment flows
-- Many users start payment process but don't complete it, leaving partial records
-- This causes conflicts when they try to pay later

-- Soft delete all stripe_customers records that don't have corresponding completed orders
-- This allows fresh customer creation on next payment attempt for all affected users
UPDATE stripe_customers 
SET deleted_at = NOW()
WHERE deleted_at IS NULL
  AND customer_id NOT IN (
    -- Keep customers who have actually completed payments
    SELECT DISTINCT so.customer_id 
    FROM stripe_orders so 
    WHERE so.status = 'completed' 
    AND so.deleted_at IS NULL
  )
  AND customer_id NOT IN (
    -- Keep customers who have active subscriptions
    SELECT DISTINCT ss.customer_id 
    FROM stripe_subscriptions ss 
    WHERE ss.status IN ('active', 'trialing') 
    AND ss.deleted_at IS NULL
  );

-- Clean up any orphaned subscription records for the cleaned up customers
UPDATE stripe_subscriptions
SET deleted_at = NOW()
WHERE deleted_at IS NULL
  AND customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE deleted_at IS NOT NULL
  );

-- Log the cleanup action
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'bulk_cleanup',
  'completed',
  jsonb_build_object(
    'action', 'cleaned_up_incomplete_customer_records',
    'timestamp', NOW(),
    'reason', 'users_with_partial_records_from_incomplete_payments'
  )
);
