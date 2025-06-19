-- Recover payment for kendranespiritu@gmail.com who was charged $3.99 monthly but account wasn't activated
-- User was charged but webhook didn't sync properly to database

-- Run the recovery function to activate their account
SELECT recover_manual_payment('kendranespiritu@gmail.com', NULL, NULL, 'monthly');

-- Log this recovery action  
INSERT INTO sync_logs (customer_id, operation, status, details)
VALUES (
  'MANUAL_RECOVERY',
  'payment_recovery_kendranespiritu',
  'completed',
  jsonb_build_object(
    'user_email', 'kendranespiritu@gmail.com',
    'payment_type', 'monthly',
    'amount_charged', 3.99,
    'reason', 'webhook_sync_failure',
    'recovery_timestamp', NOW()
  )
);
