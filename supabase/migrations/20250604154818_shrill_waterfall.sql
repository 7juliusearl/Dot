/*
  # Add email notification trigger for new signups
  
  1. Changes
    - Add function to send notification when new users sign up
    - Add trigger to call the function on user creation
  
  2. Security
    - Function runs with security definer to ensure proper permissions
*/

-- Create the notification function
CREATE OR REPLACE FUNCTION public.notify_new_signup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the Edge Function to send notification
  PERFORM
    net.http_post(
      url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/notify-signup'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key'))
      ),
      body := jsonb_build_object(
        'record', row_to_json(NEW)
      )
    );
  
  RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER notify_new_signup_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_signup();