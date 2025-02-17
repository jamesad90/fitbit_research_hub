/*
  # Update Fitbit data policies

  1. Changes
    - Drop existing policies if they exist
    - Create new policies for fitbit_data table
    - Enable read access for own data and researchers
    - Enable insert/update access for own data
  
  2. Security
    - Ensure users can only access their own data
    - Allow researchers to view all data
    - Restrict data modifications to data owners
*/

DO $$ 
BEGIN
  -- Drop existing policies if they exist
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'fitbit_data' 
    AND policyname = 'Enable read access for own data and researchers'
  ) THEN
    DROP POLICY "Enable read access for own data and researchers" ON fitbit_data;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'fitbit_data' 
    AND policyname = 'Enable insert access for own data'
  ) THEN
    DROP POLICY "Enable insert access for own data" ON fitbit_data;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'fitbit_data' 
    AND policyname = 'Enable update access for own data'
  ) THEN
    DROP POLICY "Enable update access for own data" ON fitbit_data;
  END IF;
END $$;

-- Create new policies
CREATE POLICY "Enable read access for own data and researchers"
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

CREATE POLICY "Enable insert access for own data"
  ON fitbit_data
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update access for own data"
  ON fitbit_data
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);