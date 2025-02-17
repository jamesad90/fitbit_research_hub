-- Create a function to check researcher role with a unique name
CREATE OR REPLACE FUNCTION check_is_researcher_v1()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles up
    WHERE up.user_id = auth.uid()
    AND up.role = 'researcher'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop user_profiles policies
  DROP POLICY IF EXISTS "enable_all_access_own_profile" ON user_profiles;
  DROP POLICY IF EXISTS "enable_researcher_read_all_profiles" ON user_profiles;
  
  -- Drop fitbit_data policies
  DROP POLICY IF EXISTS "enable_all_access_own_data" ON fitbit_data;
  DROP POLICY IF EXISTS "enable_researcher_read_all_data" ON fitbit_data;
  
  -- Drop user_devices policies
  DROP POLICY IF EXISTS "enable_all_access_own_devices" ON user_devices;
  DROP POLICY IF EXISTS "enable_researcher_read_all_devices" ON user_devices;
END $$;

-- Create new simplified policies for user_profiles
CREATE POLICY "user_profiles_policy"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  )
  WITH CHECK (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  );

-- Create new simplified policies for fitbit_data
CREATE POLICY "fitbit_data_policy"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  )
  WITH CHECK (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  );

-- Create new simplified policies for user_devices
CREATE POLICY "user_devices_policy"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  )
  WITH CHECK (
    auth.uid() = user_id OR
    check_is_researcher_v1()
  );

-- Create new simplified policies for invitation_codes
CREATE POLICY "invitation_codes_select_policy"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (expires_at > now());

CREATE POLICY "invitation_codes_insert_policy"
  ON invitation_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (check_is_researcher_v1());

CREATE POLICY "invitation_codes_update_policy"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (check_is_researcher_v1())
  WITH CHECK (check_is_researcher_v1());

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION check_is_researcher_v1 TO authenticated;