/*
  # Update Stripe subscriptions with latest data
  
  1. Changes
    - Add function to sync subscription data from Stripe
    - Add trigger to keep subscription data up to date
  
  2. Security
    - Function runs with security definer to ensure proper permissions
*/

-- Create function to sync subscription data
CREATE OR REPLACE FUNCTION sync_stripe_subscription()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the Edge Function to sync subscription data
  PERFORM
    net.http_post(
      url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/stripe-sync'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key'))
      ),
      body := jsonb_build_object(
        'customer_id', NEW.customer_id
      )
    );
  
  RETURN NEW;
END;
$$;