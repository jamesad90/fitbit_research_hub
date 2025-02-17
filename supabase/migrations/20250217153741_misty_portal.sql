/*
  # Fix policy recursion and researcher access

  1. Changes
    - Simplify policies to avoid recursion
    - Ensure researchers have full access
    - Fix policy dependencies
    - Add proper indexes

  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Enable researcher access to all data
*/

-- Drop existing policies
DO $$ 
BEGIN
  -- Drop policies for user_profiles
  DROP POLICY IF EXISTS "user_profiles_access" ON user_profiles;
  DROP POLICY IF EXISTS "enable_user_profile_select" ON user_profiles;
  DROP POLICY IF EXISTS "enable_user_profile_insert" ON user_profiles;
  DROP POLICY IF EXISTS "enable_user_profile_update" ON user_profiles;
  
  -- Drop policies for fitbit_data
  DROP POLICY IF EXISTS "fitbit_data_access" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_fitbit_data_select" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_fitbit_data_insert" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_fitbit_data_update" ON fitbit_data;
  
  -- Drop policies for user_devices
  DROP POLICY IF EXISTS "user_devices_access" ON user_devices;
  DROP POLICY IF EXISTS "enable_user_devices_select" ON user_devices;
  DROP POLICY IF EXISTS "enable_user_devices_insert" ON user_devices;
  DROP POLICY IF EXISTS "enable_user_devices_update" ON user_devices;
END $$;

-- Create function to check if user is researcher
CREATE OR REPLACE FUNCTION is_researcher(uid uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_id = uid 
    AND role = 'researcher'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Create new simplified policies for user_profiles
CREATE POLICY "user_profiles_select"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()));

CREATE POLICY "user_profiles_insert"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_profiles_update"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()))
  WITH CHECK (auth.uid() = user_id OR is_researcher(auth.uid()));

-- Create new simplified policies for fitbit_data
CREATE POLICY "fitbit_data_select"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()));

CREATE POLICY "fitbit_data_insert"
  ON fitbit_data
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR is_researcher(auth.uid()));

CREATE POLICY "fitbit_data_update"
  ON fitbit_data
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()))
  WITH CHECK (auth.uid() = user_id OR is_researcher(auth.uid()));

-- Create new simplified policies for user_devices
CREATE POLICY "user_devices_select"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()));

CREATE POLICY "user_devices_insert"
  ON user_devices
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR is_researcher(auth.uid()));

CREATE POLICY "user_devices_update"
  ON user_devices
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR is_researcher(auth.uid()))
  WITH CHECK (auth.uid() = user_id OR is_researcher(auth.uid()));

-- Create new simplified policies for invitation_codes
CREATE POLICY "invitation_codes_select"
  ON invitation_codes
  FOR SELECT
  TO authenticated
  USING (used_at IS NULL OR is_researcher(auth.uid()));

CREATE POLICY "invitation_codes_insert"
  ON invitation_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (is_researcher(auth.uid()));

CREATE POLICY "invitation_codes_update"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (is_researcher(auth.uid()))
  WITH CHECK (is_researcher(auth.uid()));

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id_role ON user_profiles(user_id, role);
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_id_date ON fitbit_data(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id_device ON user_devices(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires ON invitation_codes(used_at, expires_at);

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION is_researcher TO authenticated;