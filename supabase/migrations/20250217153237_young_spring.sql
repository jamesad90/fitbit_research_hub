/*
  # Update database relationships and views

  1. Changes
    - Drop existing view
    - Add foreign key relationships between tables
    - Create composite indexes for performance
    - Create views for user data with devices and groups
    - Set up proper access control

  2. Security
    - Grant appropriate access to authenticated users
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS user_data_with_devices;

-- Add foreign key relationships
ALTER TABLE fitbit_data
DROP CONSTRAINT IF EXISTS fitbit_data_user_id_fkey,
ADD CONSTRAINT fitbit_data_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

ALTER TABLE user_devices
DROP CONSTRAINT IF EXISTS user_devices_user_id_fkey,
ADD CONSTRAINT user_devices_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Create composite indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_date 
  ON fitbit_data(user_id, date);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_device 
  ON user_devices(user_id, device_id);

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
GRANT SELECT ON user_data_with_devices TO authenticated;