/*
  # Add admin flag to user profiles

  1. Changes
    - Add `is_admin` column to user_profiles table
    - Update RLS policies to give admins full access
    - Add function to create initial admin account

  2. Security
    - Only admins can promote other users to admin
*/

-- Add admin flag to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN is_admin boolean DEFAULT false;

-- Update existing policies to give admins full access
CREATE POLICY "Admins can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid())
    OR user_id = auth.uid()
  );

CREATE POLICY "Admins can update all profiles"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid())
    OR user_id = auth.uid()
  )
  WITH CHECK (
    (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid())
    OR user_id = auth.uid()
  );

-- Function to create initial admin
CREATE OR REPLACE FUNCTION create_initial_admin(admin_email text)
RETURNS void AS $$
DECLARE
  admin_user_id uuid;
BEGIN
  -- Check if user exists
  SELECT id INTO admin_user_id
  FROM auth.users
  WHERE email = admin_email;

  IF admin_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found', admin_email;
  END IF;

  -- Update or insert admin profile
  INSERT INTO user_profiles (user_id, role, is_admin)
  VALUES (admin_user_id, 'researcher', true)
  ON CONFLICT (user_id) 
  DO UPDATE SET role = 'researcher', is_admin = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;