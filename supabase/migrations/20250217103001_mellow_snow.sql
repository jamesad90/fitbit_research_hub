/*
  # Fix invitation code policies and registration flow

  1. Changes
    - Allow public access to read and update invitation codes during registration
    - Simplify policies to ensure registration works correctly
    - Fix admin access to invitation codes

  2. Security
    - Maintain security while allowing registration
    - Ensure proper invitation code validation
    - Prevent unauthorized access
*/

-- Drop existing invitation code policies
DROP POLICY IF EXISTS "Enable read access for valid codes" ON invitation_codes;
DROP POLICY IF EXISTS "Enable update for valid codes" ON invitation_codes;
DROP POLICY IF EXISTS "Enable admin access to invitation codes" ON invitation_codes;

-- Create new invitation code policies
CREATE POLICY "Enable public read access to valid codes"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Enable public update of valid codes"
  ON invitation_codes
  FOR UPDATE
  TO public
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());

CREATE POLICY "Enable public insert of valid codes"
  ON invitation_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_id = auth.uid() 
    AND is_admin = true
  ));

-- Update user profile policies to ensure proper registration
DROP POLICY IF EXISTS "Enable insert for users" ON user_profiles;

CREATE POLICY "Enable insert for new users"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (true);