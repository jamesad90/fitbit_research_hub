/*
  # Update RLS policies for fitbit_data table

  1. Changes
    - Drop existing policies for fitbit_data table
    - Create new policies that allow:
      - Researchers to insert and update data for all users
      - Users to manage their own data
      - Researchers to view all data
      - Users to view their own data

  2. Security
    - Maintains data isolation between users
    - Allows researchers to manage data for all users
    - Preserves read access for both researchers and users
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for own data and researchers" ON fitbit_data;
DROP POLICY IF EXISTS "Enable insert access for own data" ON fitbit_data;
DROP POLICY IF EXISTS "Enable update access for own data" ON fitbit_data;

-- Create new policies
CREATE POLICY "Users can view own data"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Researchers can view all data"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Users can manage own data"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Researchers can manage all data"
  ON fitbit_data
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