/*
  # Create waitlist table for beta signups
  
  1. New Tables
    - `waitlist`
      - `id` (uuid, primary key)
      - `email` (text, unique)
      - `created_at` (timestamp)
      - `status` (text) - tracks signup status
  
  2. Security
    - Enable RLS on `waitlist` table
    - Add policy for inserting new emails
    - Add policy for admins to read all entries
*/

CREATE TABLE IF NOT EXISTS waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  status text DEFAULT 'pending'
);

ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

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