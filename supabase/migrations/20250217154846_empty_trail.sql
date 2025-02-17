/*
  # Fix Policy Recursion
  
  1. Changes
    - Simplify policies to avoid recursion
    - Fix researcher access policies
    - Maintain security while avoiding circular references
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Researchers can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own data" ON fitbit_data;
DROP POLICY IF EXISTS "Researchers can view all data" ON fitbit_data;
DROP POLICY IF EXISTS "Users can manage own data" ON fitbit_data;
DROP POLICY IF EXISTS "Users can view own devices" ON user_devices;
DROP POLICY IF EXISTS "Researchers can view all devices" ON user_devices;
DROP POLICY IF EXISTS "Users can manage own devices" ON user_devices;

-- Create simplified policies for user_profiles
CREATE POLICY "enable_all_access_own_profile"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create simplified policies for fitbit_data
CREATE POLICY "enable_all_access_own_data"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create simplified policies for user_devices
CREATE POLICY "enable_all_access_own_devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create researcher access policies using a non-recursive approach
CREATE POLICY "enable_researcher_read_all_profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM user_profiles WHERE user_id = auth.uid() LIMIT 1) = 'researcher'
  );

CREATE POLICY "enable_researcher_read_all_data"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM user_profiles WHERE user_id = auth.uid() LIMIT 1) = 'researcher'
  );

CREATE POLICY "enable_researcher_read_all_devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM user_profiles WHERE user_id = auth.uid() LIMIT 1) = 'researcher'
  );