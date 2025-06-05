/*
  # Add Firebase sync trigger
  
  1. Changes
    - Add function to trigger Firebase sync on user creation
    - Add trigger to call the function when users are created
  
  2. Security
    - Function runs with security definer to ensure proper permissions
*/

-- Create the function that will trigger the Edge Function
CREATE OR REPLACE FUNCTION public.sync_user_to_firebase()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the Edge Function to sync the user to Firebase
  PERFORM
    net.http_post(
      url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/sync-firebase'),
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
DROP TRIGGER IF EXISTS sync_user_to_firebase_trigger ON auth.users;
CREATE TRIGGER sync_user_to_firebase_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_user_to_firebase();