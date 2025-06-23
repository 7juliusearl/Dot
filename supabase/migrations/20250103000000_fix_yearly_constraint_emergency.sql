-- EMERGENCY MIGRATION: Fix yearly constraint violation
-- This migration immediately fixes the constraint blocking yearly subscriptions

-- Drop the old constraint that doesn't allow yearly
ALTER TABLE stripe_orders 
DROP CONSTRAINT IF EXISTS stripe_orders_purchase_type_check;

-- Add new constraint that includes yearly
ALTER TABLE stripe_orders 
ADD CONSTRAINT stripe_orders_purchase_type_check 
CHECK (purchase_type IN ('lifetime', 'monthly', 'yearly'));

-- Fix any incomplete yearly subscriptions to be active
UPDATE stripe_orders 
SET subscription_status = 'active'
WHERE subscription_status = 'incomplete' 
  AND purchase_type = 'yearly'
  AND status = 'completed'
  AND created_at > NOW() - INTERVAL '30 days';

-- Log this emergency fix
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'SYSTEM',
  'emergency_yearly_constraint_fix',
  'completed',
  jsonb_build_object(
    'action', 'fixed_purchase_type_constraint_to_allow_yearly',
    'timestamp', NOW(),
    'issue', 'constraint_violation_blocking_yearly_subscriptions',
    'solution', 'updated_constraint_to_include_yearly_value'
  )
); 