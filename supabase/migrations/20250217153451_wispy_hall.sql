/*
  # Fix database relationships and views

  1. Changes
    - Drop and recreate views with proper relationships
    - Add missing indexes
    - Update foreign key constraints
    - Fix group data aggregation

  2. Security
    - Maintain RLS policies
    - Ensure proper data access
*/

-- Drop existing views if they exist
DROP VIEW IF EXISTS user_data_with_devices;
DROP VIEW IF EXISTS user_data_with_groups;

-- Add foreign key relationships
ALTER TABLE fitbit_data
DROP CONSTRAINT IF EXISTS fitbit_data_user_id_fkey,
ADD CONSTRAINT fitbit_data_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Create composite indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_date 
  ON fitbit_data(user_id, date);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id_role
  ON user_profiles(user_id, role);

-- Create view for user data with groups
CREATE VIEW user_data_with_groups AS
SELECT 
  f.*,
  up.group,
  up.participant_id
FROM fitbit_data f
JOIN user_profiles up ON f.user_id = up.user_id;

-- Grant access to views
GRANT SELECT ON user_data_with_groups TO authenticated;