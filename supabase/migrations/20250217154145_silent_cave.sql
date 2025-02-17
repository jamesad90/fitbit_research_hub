/*
  # Fix user_profiles table and registration

  1. Changes
    - Drop and recreate user_profiles table with proper structure
    - Add proper indexes and constraints
    - Create simplified RLS policies
    - Update registration function

  2. Security
    - Users can view and manage their own profiles
    - Researchers can view and manage all profiles
    - Proper registration flow with invitation codes
*/

-- Drop existing policies
DROP POLICY IF EXISTS "allow_select_own_profile" ON user_profiles;
DROP POLICY IF EXISTS "allow_select_all_for_researchers" ON user_profiles;
DROP POLICY IF EXISTS "allow_insert_own_profile" ON user_profiles;
DROP POLICY IF EXISTS "allow_update_own_profile" ON user_profiles;
DROP POLICY IF EXISTS "allow_update_all_for_researchers" ON user_profiles;

-- Drop and recreate user_profiles table
DROP TABLE IF EXISTS user_profiles CASCADE;

CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  group_name text,
  participant_id text,
  fitbit_access_token text,
  fitbit_refresh_token text,
  token_expires_at timestamptz,
  last_sync_at timestamptz,
  created_at timestamptz DEFAULT now(),
  is_admin boolean DEFAULT false,
  UNIQUE(user_id),
  UNIQUE(participant_id)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create simple policies
CREATE POLICY "users_own_access"
  ON user_profiles
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "researchers_full_access"
  ON user_profiles
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

-- Add indexes
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_participant_id ON user_profiles(participant_id);

-- Update registration function
CREATE OR REPLACE FUNCTION register_user(
  p_user_id uuid,
  p_role text,
  p_participant_id text,
  p_invite_code text
) RETURNS void AS $$
DECLARE
  v_code_exists boolean;
BEGIN
  -- Check if invitation code exists and is valid
  SELECT EXISTS (
    SELECT 1 FROM invitation_codes
    WHERE code = p_invite_code
    AND used_at IS NULL
    AND expires_at > now()
  ) INTO v_code_exists;

  IF NOT v_code_exists THEN
    RAISE EXCEPTION 'Invalid or expired invitation code';
  END IF;

  -- Insert user profile
  INSERT INTO user_profiles (
    user_id,
    role,
    participant_id,
    created_at
  ) VALUES (
    p_user_id,
    p_role,
    p_participant_id,
    now()
  );

  -- Mark invitation code as used
  UPDATE invitation_codes SET
    used_at = now(),
    used_by = p_user_id
  WHERE code = p_invite_code;

  -- If we get here, both operations succeeded
  RETURN;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'User profile already exists or participant ID is already taken';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to register user: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION register_user TO authenticated;