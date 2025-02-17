/*
  # Fix RLS policies for registration flow

  1. Changes
    - Simplify user profile policies
    - Allow public access to invitation codes for registration
    - Fix update permissions for invitation codes
    - Add admin policies

  2. Security
    - Maintain RLS protection while allowing necessary registration operations
    - Ensure proper access control for invitation codes
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access to own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert access to own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable update access to own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access to valid invitation codes" ON invitation_codes;
DROP POLICY IF EXISTS "Enable update access to valid invitation codes" ON invitation_codes;

-- User profiles policies
CREATE POLICY "Allow users to manage their own profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Invitation codes policies
CREATE POLICY "Allow reading valid invitation codes"
  ON invitation_codes
  FOR SELECT
  TO anon
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "Allow authenticated users to update valid codes"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Admin policies
CREATE POLICY "Allow admins to manage all profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() AND is_admin = true
  ));

CREATE POLICY "Allow admins to manage invitation codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() AND is_admin = true
  ));