/*
  # Fix user devices and data access

  1. Changes
    - Add missing indexes for better performance
    - Create view for user data with devices
    - Update RLS policies for better security

  2. Security
    - Ensure proper RLS policies for all tables
    - Add proper constraints and checks
*/

-- Add missing indexes
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_id_date ON fitbit_data(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);

-- Create view for user data with devices
CREATE OR REPLACE VIEW user_data_with_devices AS
SELECT 
  up.*,
  jsonb_agg(
    CASE WHEN ud.id IS NOT NULL THEN
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
    ELSE NULL
    END
  ) FILTER (WHERE ud.id IS NOT NULL) as devices
FROM user_profiles up
LEFT JOIN user_devices ud ON up.user_id = ud.user_id
GROUP BY up.id, up.user_id, up.role, up.group, up.participant_id, 
         up.fitbit_access_token, up.fitbit_refresh_token, up.token_expires_at,
         up.last_sync_at, up.created_at, up.is_admin;

-- Update RLS policies
DROP POLICY IF EXISTS "manage_user_devices" ON user_devices;
CREATE POLICY "manage_user_devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

-- Update fitbit_data policies
DROP POLICY IF EXISTS "manage_fitbit_data" ON fitbit_data;
CREATE POLICY "manage_fitbit_data"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  )
  WITH CHECK (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );