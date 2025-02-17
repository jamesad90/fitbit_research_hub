export interface Device {
  id: string;
  device_id: string;
  device_version: string;
  type: 'TRACKER' | 'SCALE';
  battery: 'High' | 'Medium' | 'Low' | 'Empty';
  battery_level: number;
  last_sync_time: string;
  mac: string;
  features: string[];
  created_at: string;
  updated_at: string;
}

export interface UserProfile {
  id: string;
  user_id: string;
  role: 'researcher' | 'participant';
  group: string | null;
  participant_id: string | null;
  fitbit_access_token: string | null;
  fitbit_refresh_token: string | null;
  token_expires_at: string | null;
  last_sync_at: string | null;
  created_at: string;
  is_admin: boolean;
  devices?: Device[];
}

export interface DataPoint {
  date: string;
  value: number | null;
  userId?: string;
  group?: string;
}

export interface GroupStats {
  group: string;
  mean: number;
  sd: number;
  n: number;
}