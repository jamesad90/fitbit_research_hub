/*
  # Add participant_id column to invitation_codes

  1. Changes
    - Add participant_id column to invitation_codes table
    - Add index for participant_id
*/

-- Add participant_id column to invitation_codes
ALTER TABLE invitation_codes
ADD COLUMN participant_id text;

-- Add index for participant_id
CREATE INDEX IF NOT EXISTS idx_invitation_codes_participant_id
  ON invitation_codes(participant_id);