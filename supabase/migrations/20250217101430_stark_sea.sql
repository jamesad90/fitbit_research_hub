/*
  # Fix RLS policies for user profiles and invitation codes

  1. Changes
    - Remove recursive policies that were causing infinite recursion
    - Add proper insert policies for user_profiles
    - Simplify admin access policies
    - Add missing policies for invitation codes

  2. Security
    - Maintain proper access control while fixing recursion issues
    - Ensure new users can create their profiles during registration
    - Preserve admin privileges
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Researchers can view invitation codes" ON invitation_codes;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;

-- Simplified admin check function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated policies for user_profiles
CREATE POLICY "Users can insert their own profile"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_admin());

CREATE POLICY "Admins can update profiles"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (is_admin() OR auth.uid() = user_id)
  WITH CHECK (is_admin() OR auth.uid() = user_id);

-- Updated policies for invitation_codes
CREATE POLICY "Admins can manage invitation codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (is_admin());

CREATE POLICY "Anyone can read valid codes"
  ON invitation_codes
  FOR SELECT
  TO authenticated
  USING (used_at IS NULL AND expires_at > now());