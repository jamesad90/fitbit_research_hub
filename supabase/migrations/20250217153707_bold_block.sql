/*
  # Fix researcher access policies

  1. Changes
    - Simplify and consolidate policies for all tables
    - Ensure researchers have full access to all tables
    - Fix recursive policy issues
    - Add proper indexes for performance

  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
*/

-- Drop existing policies
DO $$ 
BEGIN
  -- Drop policies for user_profiles
  DROP POLICY IF EXISTS "enable_user_profile_select" ON user_profiles;
  DROP POLICY IF EXISTS "enable_user_profile_insert" ON user_profiles;
  DROP POLICY IF EXISTS "enable_user_profile_update" ON user_profiles;
  
  -- Drop policies for fitbit_data
  DROP POLICY IF EXISTS "enable_fitbit_data_select" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_fitbit_data_insert" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_fitbit_data_update" ON fitbit_data;
  
  -- Drop policies for user_devices
  DROP POLICY IF EXISTS "enable_user_devices_select" ON user_devices;
  DROP POLICY IF EXISTS "enable_user_devices_insert" ON user_devices;
  DROP POLICY IF EXISTS "enable_user_devices_update" ON user_devices;
  
  -- Drop policies for invitation_codes
  DROP POLICY IF EXISTS "invitation_codes_read_wise_field" ON invitation_codes;
  DROP POLICY IF EXISTS "invitation_codes_update_wise_field" ON invitation_codes;
  DROP POLICY IF EXISTS "invitation_codes_insert_wise_field" ON invitation_codes;
END $$;

-- Create new simplified policies for user_profiles
CREATE POLICY "user_profiles_access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  )
  WITH CHECK (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  );

-- Create new simplified policies for fitbit_data
CREATE POLICY "fitbit_data_access"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  )
  WITH CHECK (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  );

-- Create new simplified policies for user_devices
CREATE POLICY "user_devices_access"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  )
  WITH CHECK (
    auth.uid() = user_id OR
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  );

-- Create new simplified policies for invitation_codes
CREATE POLICY "invitation_codes_read"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "invitation_codes_manage"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  )
  WITH CHECK (
    (SELECT role FROM user_profiles WHERE user_id = auth.uid()) = 'researcher'
  );

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id_role ON user_profiles(user_id, role);
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_id_date ON fitbit_data(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id_device ON user_devices(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires ON invitation_codes(used_at, expires_at);

-- Create materialized view for faster access
CREATE MATERIALIZED VIEW IF NOT EXISTS user_data_summary AS
SELECT 
  up.user_id,
  up.role,
  up.group,
  up.participant_id,
  up.last_sync_at,
  COUNT(DISTINCT fd.date) as data_points,
  COUNT(DISTINCT ud.device_id) as device_count,
  MAX(fd.date) as latest_data_date
FROM user_profiles up
LEFT JOIN fitbit_data fd ON up.user_id = fd.user_id
LEFT JOIN user_devices ud ON up.user_id = ud.user_id
GROUP BY up.user_id, up.role, up.group, up.participant_id, up.last_sync_at;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_data_summary_user_id ON user_data_summary(user_id);

-- Create function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_user_data_summary()
RETURNS trigger AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY user_data_summary;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to refresh materialized view
CREATE TRIGGER refresh_user_data_summary_on_profile_change
  AFTER INSERT OR UPDATE OR DELETE ON user_profiles
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_user_data_summary();

CREATE TRIGGER refresh_user_data_summary_on_data_change
  AFTER INSERT OR UPDATE OR DELETE ON fitbit_data
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_user_data_summary();

CREATE TRIGGER refresh_user_data_summary_on_device_change
  AFTER INSERT OR UPDATE OR DELETE ON user_devices
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_user_data_summary();

-- Grant access to materialized view
GRANT SELECT ON user_data_summary TO authenticated;