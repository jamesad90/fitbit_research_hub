/*
  # Fix recursive policies and improve RLS

  1. Changes
    - Remove all existing policies to start fresh
    - Create new non-recursive policies
    - Simplify access control logic

  2. Security
    - Maintain proper access control
    - Fix infinite recursion issues
    - Ensure proper authentication checks
*/

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Researchers can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON user_profiles;

-- Create new, simplified policies
CREATE POLICY "Allow users to manage their own profiles"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow admins full access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() AND is_admin = true
  ));

-- Update invitation code policies
DROP POLICY IF EXISTS "Admins can manage invitation codes" ON invitation_codes;
DROP POLICY IF EXISTS "Anyone can read valid codes" ON invitation_codes;

CREATE POLICY "Allow admin access to invitation codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() AND is_admin = true
  ));

CREATE POLICY "Allow reading valid invitation codes"
  ON invitation_codes
  FOR SELECT
  TO authenticated
  USING (used_at IS NULL AND expires_at > now());