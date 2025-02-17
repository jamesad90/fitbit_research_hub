/*
  # Fix RLS policies to prevent recursion

  1. Changes
    - Drop existing recursive policies
    - Create new non-recursive policies
    - Simplify policy conditions
    - Add proper indexes

  2. Security
    - Maintain data access control
    - Prevent infinite recursion
    - Ensure proper authorization
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile and researchers can view all" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own data and researchers can view all" ON fitbit_data;
DROP POLICY IF EXISTS "Users can view own devices and researchers can view all" ON user_devices;

-- Create new non-recursive policies for user_profiles
CREATE POLICY "enable_user_profile_select"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR
    role = 'researcher'
  );

CREATE POLICY "enable_user_profile_insert"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enable_user_profile_update"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create new non-recursive policies for fitbit_data
CREATE POLICY "enable_fitbit_data_select"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
      AND user_profiles.id IS NOT NULL
    )
  );

CREATE POLICY "enable_fitbit_data_insert"
  ON fitbit_data
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enable_fitbit_data_update"
  ON fitbit_data
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create new non-recursive policies for user_devices
CREATE POLICY "enable_user_devices_select"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
      AND user_profiles.id IS NOT NULL
    )
  );

CREATE POLICY "enable_user_devices_insert"
  ON user_devices
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enable_user_devices_update"
  ON user_devices
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add indexes to improve performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_user_id
  ON user_profiles(role, user_id);

CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_id_date
  ON fitbit_data(user_id, date);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id_device
  ON user_devices(user_id, device_id);