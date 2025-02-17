/*
  # Add invitation codes system

  1. New Tables
    - `invitation_codes`
      - `code` (text, primary key) - The unique invitation code
      - `role` (text) - The role to assign to the user (researcher/participant)
      - `used_at` (timestamptz) - When the code was used (null if unused)
      - `used_by` (uuid) - Reference to the user who used the code
      - `created_at` (timestamptz) - When the code was created
      - `expires_at` (timestamptz) - When the code expires

  2. Security
    - Enable RLS on `invitation_codes` table
    - Add policy for authenticated researchers to view and create codes
    - Add policy for anyone to use a code during registration
*/

CREATE TABLE IF NOT EXISTS invitation_codes (
  code text PRIMARY KEY,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  used_at timestamptz,
  used_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz NOT NULL,
  CONSTRAINT valid_dates CHECK (expires_at > created_at)
);

ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;

-- Allow researchers to view and create invitation codes
CREATE POLICY "Researchers can view invitation codes"
  ON invitation_codes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Researchers can create invitation codes"
  ON invitation_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

-- Allow anyone to read unused codes during registration
CREATE POLICY "Anyone can read unused codes"
  ON invitation_codes
  FOR SELECT
  TO anon
  USING (used_at IS NULL AND expires_at > now());