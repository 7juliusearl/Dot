/*
  # App Store Configuration Table
  
  1. New Tables
    - `app_store_config`: Stores App Store Connect API configuration
      - `id` (uuid, primary key)
      - `key_id` (text)
      - `issuer_id` (text)
      - `app_id` (text)
      - Timestamps for created_at and updated_at
  
  2. Security
    - Enable RLS
    - Restrict all access to system processes only
*/

CREATE TABLE IF NOT EXISTS app_store_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key_id text NOT NULL,
  issuer_id text NOT NULL,
  app_id text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE app_store_config ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "No direct access to app store config" ON app_store_config;
END $$;

-- Create new policy
CREATE POLICY "No direct access to app store config"
  ON app_store_config
  FOR ALL
  TO authenticated
  USING (false);

-- Insert the configuration
INSERT INTO app_store_config (key_id, issuer_id, app_id)
VALUES (
  'U6D6PTLQZR',
  '586fb9b7-de4b-493d-8b24-8be2d86cce2d',
  '6744261945'
);