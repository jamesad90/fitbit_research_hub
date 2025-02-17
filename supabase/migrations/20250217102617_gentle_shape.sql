-- Drop existing policies
DROP POLICY IF EXISTS "Users can manage own profile" ON user_profiles;
DROP POLICY IF EXISTS "Manage invitation codes" ON invitation_codes;

-- Create simplified policies for user_profiles
CREATE POLICY "Enable read access to own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Enable insert access to own profile"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable update access to own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create simplified policies for invitation_codes
CREATE POLICY "Enable read access to valid invitation codes"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "Enable update access to valid invitation codes"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());