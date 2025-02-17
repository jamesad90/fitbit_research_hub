/*
  # Add group column to user_profiles table

  1. Changes
    - Add 'group' column to user_profiles table for participant grouping
*/

-- Add group column to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN "group" text;

-- Update existing policies to include the new column
DROP POLICY IF EXISTS "Enable read access for users" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for users and admins" ON user_profiles;

CREATE POLICY "Enable read access for users"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_admin = true);

CREATE POLICY "Enable update for users and admins"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR is_admin = true)
  WITH CHECK (auth.uid() = user_id OR is_admin = true);