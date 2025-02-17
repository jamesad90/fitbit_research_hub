/*
  # Add register_user function

  1. New Functions
    - `register_user`: Handles user registration transaction
      - Creates user profile
      - Updates invitation code status
      - Ensures atomic operation

  2. Changes
    - Added SECURITY DEFINER to ensure function runs with elevated privileges
    - Added proper error handling
    - Ensures transaction integrity
*/

CREATE OR REPLACE FUNCTION register_user(
  p_user_id uuid,
  p_role text,
  p_participant_id text,
  p_invite_code text
) RETURNS void AS $$
BEGIN
  -- Verify the invitation code is still valid
  IF NOT EXISTS (
    SELECT 1 FROM invitation_codes
    WHERE code = p_invite_code
    AND used_at IS NULL
    AND expires_at > now()
  ) THEN
    RAISE EXCEPTION 'Invalid or expired invitation code';
  END IF;

  -- Start transaction
  BEGIN
    -- Insert user profile
    INSERT INTO user_profiles (
      user_id,
      role,
      participant_id,
      created_at
    )
    VALUES (
      p_user_id,
      p_role,
      p_participant_id,
      now()
    );

    -- Update invitation code
    UPDATE invitation_codes
    SET 
      used_at = now(),
      used_by = p_user_id
    WHERE code = p_invite_code;

    -- If we get here, both operations succeeded
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      -- Roll back the transaction
      RAISE EXCEPTION 'Failed to register user: %', SQLERRM;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;