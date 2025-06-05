/*
  # Remove Firebase Integration
  
  1. Changes
    - Drop the Firebase sync trigger
    - Drop the Firebase sync function
  
  2. Security
    - No impact on existing RLS policies
    - Maintains data integrity
*/

-- Drop the trigger first
DROP TRIGGER IF EXISTS sync_user_to_firebase_trigger ON auth.users;

-- Drop the function
DROP FUNCTION IF EXISTS public.sync_user_to_firebase();