/*
  # Fix database relationships and views

  1. Changes
    - Drop existing views
    - Create proper relationships between tables
    - Create new views with proper joins
    - Update RLS policies

  2. Security
    - Maintain RLS policies
    - Grant appropriate access to views
*/

-- Drop existing views
DROP VIEW IF EXISTS user_data_with_devices;
DROP VIEW IF EXISTS user_data_with_groups;

-- Create view for user data with groups
CREATE VIEW user_data_with_groups AS
SELECT 
  f.*,
  up.group,
  up.participant_id
FROM fitbit_data f
JOIN user_profiles up ON f.user_id = up.user_id;

-- Create view for user data with devices
CREATE VIEW user_data_with_devices AS
SELECT 
  up.*,
  jsonb_agg(
    jsonb_build_object(
      'id', ud.id,
      'device_id', ud.device_id,
      'device_version', ud.device_version,
      'type', ud.type,
      'battery', ud.battery,
      'battery_level', ud.battery_level,
      'last_sync_time', ud.last_sync_time,
      'mac', ud.mac,
      'features', ud.features,
      'created_at', ud.created_at,
      'updated_at', ud.updated_at
    )
  ) FILTER (WHERE ud.id IS NOT NULL) as devices
FROM user_profiles up
LEFT JOIN user_devices ud ON up.user_id = ud.user_id
GROUP BY up.id, up.user_id, up.role, up.group, up.participant_id, 
         up.fitbit_access_token, up.fitbit_refresh_token, up.token_expires_at,
         up.last_sync_at, up.created_at, up.is_admin;

-- Grant access to views
GRANT SELECT ON user_data_with_groups TO authenticated;
GRANT SELECT ON user_data_with_devices TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_date 
  ON fitbit_data(user_id, date);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_device 
  ON user_devices(user_id, device_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id
  ON user_profiles(user_id);

-- Update RLS policies for views
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitbit_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Create policies for user_profiles
CREATE POLICY "Users can view own profile and researchers can view all"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

-- Create policies for fitbit_data
CREATE POLICY "Users can view own data and researchers can view all"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

-- Create policies for user_devices
CREATE POLICY "Users can view own devices and researchers can view all"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );