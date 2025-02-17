/*
  # Fix infinite recursion in RLS policies

  1. Changes
    - Simplify RLS policies to prevent recursion
    - Remove circular dependencies in admin checks
    - Maintain security while allowing necessary operations

  2. Security
    - Maintain proper access control
    - Prevent unauthorized access
    - Allow registration flow to work correctly
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow users to manage their own profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow admins to manage all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow reading valid invitation codes" ON invitation_codes;
DROP POLICY IF EXISTS "Allow authenticated users to update valid codes" ON invitation_codes;
DROP POLICY IF EXISTS "Allow admins to manage invitation codes" ON invitation_codes;

-- Simple, non-recursive policies for user_profiles
CREATE POLICY "Enable read access for users"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_admin = true);

CREATE POLICY "Enable insert for users"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update for users and admins"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR is_admin = true)
  WITH CHECK (auth.uid() = user_id OR is_admin = true);

-- Simple policies for invitation_codes
CREATE POLICY "Enable read access for valid codes"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "Enable update for valid codes"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());

CREATE POLICY "Enable admin access to invitation codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_id = auth.uid() 
    AND is_admin = true
  ));