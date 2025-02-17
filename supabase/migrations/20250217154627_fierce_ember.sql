/*
  # Clean Slate Migration
  
  1. Tables
    - Drop and recreate all tables with proper structure
    - Set up proper relationships and constraints
    - Enable RLS on all tables
  
  2. Policies
    - Simple, clear policies for data access
    - Proper separation between user and researcher access
    
  3. Relationships
    - Added proper foreign key relationships between tables
    - Added necessary indexes for joins
*/

-- Drop existing tables
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS fitbit_data CASCADE;
DROP TABLE IF EXISTS invitation_codes CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Create user_profiles table first (parent table)
CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  group_name text,
  participant_id text UNIQUE,
  fitbit_access_token text,
  fitbit_refresh_token text,
  token_expires_at timestamptz,
  last_sync_at timestamptz,
  created_at timestamptz DEFAULT now(),
  is_admin boolean DEFAULT false
);

-- Create fitbit_data table with proper relationship
CREATE TABLE fitbit_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
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

-- Create user_devices table with proper relationship
CREATE TABLE user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
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
  used_by uuid REFERENCES user_profiles(user_id),
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz NOT NULL,
  CONSTRAINT valid_dates CHECK (expires_at > created_at)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitbit_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;

-- Create policies for user_profiles
CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Researchers can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Users can insert own profile"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create policies for fitbit_data
CREATE POLICY "Users can view own data"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Researchers can view all data"
  ON fitbit_data
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Users can manage own data"
  ON fitbit_data
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create policies for user_devices
CREATE POLICY "Users can view own devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Researchers can view all devices"
  ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'researcher'
    )
  );

CREATE POLICY "Users can manage own devices"
  ON user_devices
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create policies for invitation_codes
CREATE POLICY "Anyone can read valid codes"
  ON invitation_codes
  FOR SELECT
  TO public
  USING (used_at IS NULL AND expires_at > now());

CREATE POLICY "Users can update valid codes"
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
  v_code_role text;
BEGIN
  -- Check if invitation code exists and is valid
  SELECT EXISTS (
    SELECT 1 FROM invitation_codes
    WHERE code = p_invite_code
    AND used_at IS NULL
    AND expires_at > now()
  ), role INTO v_code_exists, v_code_role
  FROM invitation_codes
  WHERE code = p_invite_code;

  IF NOT v_code_exists THEN
    RAISE EXCEPTION 'Invalid or expired invitation code';
  END IF;

  -- Verify role matches invitation code
  IF v_code_role != p_role THEN
    RAISE EXCEPTION 'Role does not match invitation code';
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

-- Create views for easier data access
CREATE VIEW user_data_with_devices AS
SELECT 
  up.*,
  jsonb_agg(
    jsonb_build_object(
      'id', ud.id,
      'device_id', ud.device_id,
      'device_version', ud.device_version,
      'type', ud.type,
      'battery', ud.battery,
      'battery_level', ud.battery_level,
      'last_sync_time', ud.last_sync_time,
      'mac', ud.mac,
      'features', ud.features
    )
  ) FILTER (WHERE ud.id IS NOT NULL) as devices
FROM user_profiles up
LEFT JOIN user_devices ud ON up.user_id = ud.user_id
GROUP BY up.id;

CREATE VIEW user_data_with_groups AS
SELECT 
  f.*,
  up.group_name,
  up.participant_id
FROM fitbit_data f
JOIN user_profiles up ON f.user_id = up.user_id;

-- Grant access to views
GRANT SELECT ON user_data_with_devices TO authenticated;
GRANT SELECT ON user_data_with_groups TO authenticated;