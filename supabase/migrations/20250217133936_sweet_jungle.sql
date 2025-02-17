/*
  # Fix invitation codes system

  1. Changes
    - Drop all existing policies to start fresh
    - Create new policies with proper permissions
    - Add missing indexes
*/

-- Drop all existing policies on invitation_codes
DO $$ 
BEGIN
  -- Drop policies if they exist
  DECLARE
    policy_name text;
  BEGIN
    FOR policy_name IN (
      SELECT policyname 
      FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = 'invitation_codes'
    )
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON invitation_codes', policy_name);
    END LOOP;
  END;
END $$;

-- Create new policies for invitation_codes
CREATE POLICY "invitation_codes_read_wise_field"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "invitation_codes_update_wise_field"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());

CREATE POLICY "invitation_codes_insert_wise_field"
  ON invitation_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_id = auth.uid() 
    AND is_admin = true
  ));

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires_wise_field
  ON invitation_codes(used_at, expires_at);

CREATE INDEX IF NOT EXISTS idx_invitation_codes_code_wise_field
  ON invitation_codes(code);

-- Ensure user_profiles has correct registration policy
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'user_profiles' 
    AND policyname IN ('Enable insert for new users', 'user_profiles_insert_20250217', 'user_profiles_insert_wise_field')
  ) THEN
    DROP POLICY IF EXISTS "Enable insert for new users" ON user_profiles;
    DROP POLICY IF EXISTS "user_profiles_insert_20250217" ON user_profiles;
    DROP POLICY IF EXISTS "user_profiles_insert_wise_field" ON user_profiles;
  END IF;
END $$;

CREATE POLICY "user_profiles_insert_wise_field_v2"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);