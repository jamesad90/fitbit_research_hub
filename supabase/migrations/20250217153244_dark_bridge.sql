/*
  # Create user devices table and update views

  1. Changes
    - Create user_devices table if it doesn't exist
    - Add necessary indexes
    - Update existing views with proper joins
*/

-- Create user_devices table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_version text,
  type text,
  battery jsonb,
  battery_level integer,
  last_sync_time timestamptz,
  mac text,
  features jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, device_id)
);

-- Enable RLS on user_devices
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Create policies for user_devices
CREATE POLICY "Users can view their own devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create indexes for user_devices
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id
  ON user_devices(user_id);

CREATE INDEX IF NOT EXISTS idx_user_devices_device_id
  ON user_devices(device_id);

-- Drop and recreate the user_data_with_groups view
DROP VIEW IF EXISTS user_data_with_groups;
CREATE VIEW user_data_with_groups AS
SELECT 
  f.*,
  up.group,
  up.participant_id
FROM fitbit_data f
JOIN user_profiles up ON f.user_id = up.user_id;

-- Grant access to views
GRANT SELECT ON user_data_with_groups TO authenticated;