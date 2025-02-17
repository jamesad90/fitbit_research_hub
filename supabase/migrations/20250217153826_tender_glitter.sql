/*
  # Fresh Database Schema

  1. Tables
    - user_profiles: Store user information and roles
    - fitbit_data: Store health metrics from Fitbit
    - user_devices: Store Fitbit device information
    - invitation_codes: Manage registration codes

  2. Security
    - Enable RLS on all tables
    - Create non-recursive policies
    - Ensure proper access control for researchers and participants

  3. Performance
    - Add appropriate indexes
    - Create efficient views for common queries
*/

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist
DROP TABLE IF EXISTS user_devices CASCADE;
DROP TABLE IF EXISTS fitbit_data CASCADE;
DROP TABLE IF EXISTS invitation_codes CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Create user_profiles table
CREATE TABLE user_profiles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  group_name text,
  participant_id text UNIQUE,
  fitbit_access_token text,
  fitbit_refresh_token text,
  token_expires_at timestamptz,
  last_sync_at timestamptz,
  created_at timestamptz DEFAULT now(),
  is_admin boolean DEFAULT false,
  UNIQUE(user_id)
);

-- Create fitbit_data table
CREATE TABLE fitbit_data (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Create function to check if user is researcher
CREATE OR REPLACE FUNCTION is_researcher(uid uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = uid
    AND role = 'researcher'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS on all tables
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
  USING (is_researcher(auth.uid()));

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Researchers can update all profiles"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (is_researcher(auth.uid()))
  WITH CHECK (is_researcher(auth.uid()));

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
  USING (is_researcher(auth.uid()));

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
  USING (is_researcher(auth.uid()));

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

CREATE POLICY "Researchers can manage codes"
  ON invitation_codes
  FOR ALL
  TO authenticated
  USING (is_researcher(auth.uid()))
  WITH CHECK (is_researcher(auth.uid()));

-- Create indexes for better performance
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_fitbit_data_user_date ON fitbit_data(user_id, date);
CREATE INDEX idx_user_devices_user_device ON user_devices(user_id, device_id);
CREATE INDEX idx_invitation_codes_used_expires ON invitation_codes(used_at, expires_at);

-- Create view for user data with devices
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

-- Create view for user data with groups
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

-- Create registration function
CREATE OR REPLACE FUNCTION register_user(
  p_user_id uuid,
  p_role text,
  p_participant_id text,
  p_invite_code text
) RETURNS void AS $$
BEGIN
  -- Verify the invitation code
  IF NOT EXISTS (
    SELECT 1 FROM invitation_codes
    WHERE code = p_invite_code
    AND used_at IS NULL
    AND expires_at > now()
  ) THEN
    RAISE EXCEPTION 'Invalid or expired invitation code';
  END IF;

  -- Create user profile
  INSERT INTO user_profiles (
    user_id,
    role,
    participant_id
  ) VALUES (
    p_user_id,
    p_role,
    p_participant_id
  );

  -- Mark invitation code as used
  UPDATE invitation_codes SET
    used_at = now(),
    used_by = p_user_id
  WHERE code = p_invite_code;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;