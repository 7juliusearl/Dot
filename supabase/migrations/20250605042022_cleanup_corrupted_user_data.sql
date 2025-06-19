-- Clean up corrupted data for kendranespiritu@gmail.com user
-- This user has corrupted/partial records causing customer mapping failures
-- User ID from error logs: beef2e59-1cdf-408a-a2f2-c56e07a723bc

-- Soft delete any existing problematic customer records for this user
-- This will allow fresh customer creation on next payment attempt
UPDATE stripe_customers 
SET deleted_at = NOW()
WHERE user_id = 'beef2e59-1cdf-408a-a2f2-c56e07a723bc'
  AND deleted_at IS NULL;

-- Clean up any orphaned subscription records for this user
UPDATE stripe_subscriptions
SET deleted_at = NOW()
WHERE customer_id IN (
  SELECT customer_id FROM stripe_customers 
  WHERE user_id = 'beef2e59-1cdf-408a-a2f2-c56e07a723bc'
)
AND deleted_at IS NULL;
