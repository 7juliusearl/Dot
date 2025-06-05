/*
  # Create waitlist table and policies

  1. New Tables
    - `waitlist`
      - `id` (uuid, primary key)
      - `email` (text, unique)
      - `created_at` (timestamp)
      - `status` (text, default 'pending')
  
  2. Security
    - Enable RLS on waitlist table
    - Add policy for public users to insert
    - Add policy for admin users to view entries
*/

-- Create the waitlist table
CREATE TABLE IF NOT EXISTS waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  status text DEFAULT 'pending'
);

-- Enable Row Level Security
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Anyone can sign up for waitlist" ON waitlist;
  DROP POLICY IF EXISTS "Only admins can view waitlist" ON waitlist;
END $$;

-- Create policies
CREATE POLICY "Anyone can sign up for waitlist"
  ON waitlist
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Only admins can view waitlist"
  ON waitlist
  FOR SELECT
  TO authenticated
  USING (auth.role() = 'admin');