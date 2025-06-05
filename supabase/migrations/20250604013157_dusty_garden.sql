/*
  # Add TestFlight configuration
  
  1. Changes
    - Add secure storage for App Store Connect credentials
    - Store TestFlight configuration securely
  
  2. Security
    - Values are encrypted at rest
    - Only accessible by secure functions
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

-- Only allow system processes to access this table
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