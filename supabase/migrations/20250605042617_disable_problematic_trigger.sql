-- Temporarily disable the problematic trigger causing the 'status' field error
-- This will allow payments to work while we debug the issue

-- Drop the problematic trigger on stripe_customers table
DROP TRIGGER IF EXISTS sync_subscription_on_customer_trigger ON stripe_customers;
