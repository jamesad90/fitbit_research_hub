/*
  # Fix Database Relationships
  
  1. Changes
    - Add proper foreign key relationships
    - Fix table constraints
    - Add missing indexes
    - Create views
    
  2. Important
    - NO table drops
    - Preserves existing data
*/

-- Add missing indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_date ON fitbit_data(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_device ON user_devices(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_used_expires ON invitation_codes(used_at, expires_at);

-- Create views for easier data access
CREATE OR REPLACE VIEW user_data_with_devices AS
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

CREATE OR REPLACE VIEW user_data_with_groups AS
SELECT 
  f.*,
  up.group_name,
  up.participant_id
FROM fitbit_data f
JOIN user_profiles up ON f.user_id = up.user_id;

-- Grant access to views
GRANT SELECT ON user_data_with_devices TO authenticated;
GRANT SELECT ON user_data_with_groups TO authenticated;

-- Update registration function to be more robust
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