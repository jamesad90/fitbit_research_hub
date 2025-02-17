/*
  # Fix user devices relationship

  1. Changes
    - Drop and recreate user_devices table with proper relationships
    - Add necessary indexes
    - Update RLS policies
    - Create proper view for user data with devices

  2. Security
    - Maintain RLS policies
    - Ensure proper data access
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS user_data_with_devices;

-- Recreate user_devices table with proper relationships
DROP TABLE IF EXISTS user_devices;
CREATE TABLE user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_version text,
  type text CHECK (type IN ('TRACKER', 'SCALE')),
  battery text CHECK (battery IN ('High', 'Medium', 'Low', 'Empty')),
  battery_level integer CHECK (battery_level BETWEEN 0 AND 100),
  last_sync_time timestamptz,
  mac text,
  features jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, device_id)
);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view own devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Researchers can view all devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Users can manage own devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add indexes
CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_user_devices_device_id ON user_devices(device_id);
CREATE INDEX idx_user_devices_type ON user_devices(type);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_devices_updated_at
  BEFORE UPDATE ON user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();