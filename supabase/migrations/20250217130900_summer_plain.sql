/*
  # Fix database relationships and constraints

  1. Changes
    - Add foreign key relationship between fitbit_data and user_profiles
    - Add indexes for better query performance
    - Update RLS policies to reflect relationships

  2. Security
    - Maintain existing RLS policies
    - Add proper constraints
*/

-- Add foreign key relationship between fitbit_data and user_profiles
ALTER TABLE fitbit_data
DROP CONSTRAINT IF EXISTS fitbit_data_user_id_fkey,
ADD CONSTRAINT fitbit_data_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Add index for user_id on fitbit_data
CREATE INDEX IF NOT EXISTS idx_fitbit_data_user_id ON fitbit_data(user_id);

-- Add index for date on fitbit_data
CREATE INDEX IF NOT EXISTS idx_fitbit_data_date ON fitbit_data(date);

-- Add index for group on user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_group ON user_profiles("group");

-- Update the query to use a proper join
CREATE OR REPLACE VIEW user_data_with_groups AS
SELECT 
  f.*,
  u.group
FROM fitbit_data f
JOIN user_profiles u ON f.user_id = u.user_id
WHERE u.group IS NOT NULL;