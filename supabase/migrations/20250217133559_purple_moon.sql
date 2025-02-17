/*
  # Fix invitation codes policies

  1. Changes
    - Drop existing policies safely
    - Create new policies with unique names
    - Add performance indexes
*/

-- First drop all existing policies on invitation_codes to avoid conflicts
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

-- Create new policies with unique names
CREATE POLICY "invitation_codes_read_wise_field"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "invitation_codes_update_wise_field"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());

-- Add indexes to improve performance
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires_wise_field
  ON invitation_codes(used_at, expires_at);

-- Drop existing user_profiles policies if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'user_profiles' 
    AND policyname IN ('Enable insert for new users', 'user_profiles_insert_20250217')
  ) THEN
    DROP POLICY IF EXISTS "Enable insert for new users" ON user_profiles;
    DROP POLICY IF EXISTS "user_profiles_insert_20250217" ON user_profiles;
  END IF;
END $$;

-- Create new user_profiles policy with unique name
CREATE POLICY "user_profiles_insert_wise_field"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Add helpful indexes for user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id_wise_field
  ON user_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_role_wise_field
  ON user_profiles(role);