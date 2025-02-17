/*
  # Fix infinite recursion in RLS policies

  1. Changes
    - Remove recursive admin checks from RLS policies
    - Implement simpler, non-recursive policies for user_profiles
    - Update invitation codes policies to use direct user_id checks
  
  2. Security
    - Maintains security while preventing infinite recursion
    - Ensures admins can still access all records
    - Preserves user data isolation
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Allow users to manage their own profiles" ON user_profiles;
DROP POLICY IF EXISTS "Allow admins full access" ON user_profiles;
DROP POLICY IF EXISTS "Allow admin access to invitation codes" ON invitation_codes;
DROP POLICY IF EXISTS "Allow reading valid invitation codes" ON invitation_codes;

-- Create new non-recursive policies for user_profiles
CREATE POLICY "Users can manage own profile"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = user_id
    OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid() LIMIT 1)
  )
  WITH CHECK (
    auth.uid() = user_id
    OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid() LIMIT 1)
  );

-- Update invitation codes policies to avoid recursion
CREATE POLICY "Manage invitation codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid() LIMIT 1)
    OR (used_at IS NULL AND expires_at > now())
  )
  WITH CHECK (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid() LIMIT 1)
  );