/*
  # Clean Slate Migration
  
  1. Tables
    - Drop and recreate all tables with proper structure
    - Set up proper relationships and constraints
    - Enable RLS on all tables
  
  2. Policies
    - Simple, clear policies for data access
    - Proper separation between user and researcher access
*/

-- Drop existing tables
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS fitbit_data CASCADE;
DROP TABLE IF EXISTS invitation_codes CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Create user_profiles table
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

-- Create fitbit_data table
CREATE TABLE fitbit_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  heart_rate jsonb,
  sleep jsonb,
  oxygen_saturation jsonb,
  hrv jsonb,
  respiratory_rate jsonb,
  temperature jsonb,
  ecg jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, date)
);

-- Create user_devices table
CREATE TABLE user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_version text,
  type text CHECK (type IN ('TRACKER', 'SCALE')),
  battery text CHECK (battery IN ('High', 'Medium', 'Low', 'Empty')),
  battery_level integer CHECK (battery_level BETWEEN 0 AND 100),
  last_sync_time timestamptz,
  mac text,
  features jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, device_id)
);

-- Create invitation_codes table
CREATE TABLE invitation_codes (
  code text PRIMARY KEY,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  participant_id text,
  used_at timestamptz,
  used_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz NOT NULL,
  CONSTRAINT valid_dates CHECK (expires_at > created_at)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitbit_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;

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

-- Create registration function
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

-- Add indexes for better performance
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_fitbit_data_user_date ON fitbit_data(user_id, date);
CREATE INDEX idx_user_devices_user_device ON user_devices(user_id, device_id);
CREATE INDEX idx_invitation_codes_used_expires ON invitation_codes(used_at, expires_at);