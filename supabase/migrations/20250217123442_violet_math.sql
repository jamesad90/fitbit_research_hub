/*
  # Add participant ID and last sync fields
  
  1. Changes
    - Add participant_id column to user_profiles
    - Add last_sync_at column to user_profiles
  
  2. Notes
    - participant_id is optional and unique when set
    - last_sync_at tracks the most recent Fitbit sync
*/

-- Add new columns to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN participant_id text UNIQUE,
ADD COLUMN last_sync_at timestamptz;

-- Create function to update last_sync_at
CREATE OR REPLACE FUNCTION update_user_last_sync()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE user_profiles
  SET last_sync_at = NEW.created_at
  WHERE user_id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update last_sync_at when new fitbit data is added
CREATE TRIGGER update_last_sync_trigger
  AFTER INSERT ON fitbit_data
  FOR EACH ROW
  EXECUTE FUNCTION update_user_last_sync();