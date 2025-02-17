/*
  # Fix registration and invitation code policies

  1. Changes
    - Drop and recreate invitation code policies with unique names
    - Add performance indexes
    - Update user profile registration policy
    - Ensure proper permissions for registration flow
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
CREATE POLICY "invitation_codes_read_20250217"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "invitation_codes_update_20250217"
  ON invitation_codes
  FOR UPDATE
  TO authenticated
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (used_at IS NULL AND expires_at > now());

-- Add indexes to improve performance
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires_20250217
  ON invitation_codes(used_at, expires_at);

-- Update user_profiles registration policy
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'user_profiles' 
    AND policyname = 'Enable insert for new users'
  ) THEN
    DROP POLICY "Enable insert for new users" ON user_profiles;
  END IF;
END $$;

CREATE POLICY "user_profiles_insert_20250217"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Add helpful indexes for user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id_20250217
  ON user_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_role_20250217
  ON user_profiles(role);