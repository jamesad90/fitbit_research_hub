/*
  # Add device tracking

  1. New Tables
    - `user_devices`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references user_profiles)
      - `device_id` (text)
      - `device_version` (text)
      - `type` (text)
      - `battery` (text)
      - `battery_level` (integer)
      - `last_sync_time` (timestamptz)
      - `mac` (text)
      - `features` (jsonb)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `user_devices` table
    - Add policies for users and researchers
*/

-- Create user_devices table
CREATE TABLE IF NOT EXISTS user_devices (
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

-- Add updated_at trigger
CREATE TRIGGER update_user_devices_updated_at
  BEFORE UPDATE ON user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Create policies
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

CREATE POLICY "Researchers can manage all devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

-- Add indexes
CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_user_devices_device_id ON user_devices(device_id);
CREATE INDEX idx_user_devices_type ON user_devices(type);