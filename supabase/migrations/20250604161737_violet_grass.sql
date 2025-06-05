/*
  # Remove email notification system
  
  1. Changes
    - Drop the notification trigger from auth.users table
    - Drop the notification function
  
  2. Security
    - No security changes needed
*/

-- Drop the trigger first
DROP TRIGGER IF EXISTS notify_new_signup_trigger ON auth.users;

-- Drop the function
DROP FUNCTION IF EXISTS public.notify_new_signup();