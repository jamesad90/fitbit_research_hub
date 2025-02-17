/*
  # Initial Schema Setup for Fitbit Health Dashboard

  1. New Tables
    - `user_profiles`
      - Stores user role and Fitbit authentication details
      - Links to Supabase auth.users
    - `fitbit_data`
      - Stores all Fitbit health data
      - Organized by user and date
      - Uses JSONB for flexible data storage

  2. Security
    - RLS enabled on all tables
    - Researchers can view all data
    - Participants can only view their own data
*/

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('researcher', 'participant')),
  fitbit_access_token text,
  fitbit_refresh_token text,
  token_expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Create fitbit_data table
CREATE TABLE IF NOT EXISTS fitbit_data (
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

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fitbit_data ENABLE ROW LEVEL SECURITY;

-- Policies for user_profiles
CREATE POLICY "Users can view their own profile"
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

-- Policies for fitbit_data
CREATE POLICY "Users can view their own data"
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

-- Policies for data insertion/update
CREATE POLICY "Users can insert their own data"
  ON fitbit_data
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own data"
  ON fitbit_data
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);