export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      fitbit_data: {
        Row: {
          id: string
          user_id: string
          date: string
          heart_rate: Json
          sleep: Json
          oxygen_saturation: Json
          hrv: Json
          respiratory_rate: Json
          temperature: Json
          ecg: Json
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          date: string
          heart_rate?: Json
          sleep?: Json
          oxygen_saturation?: Json
          hrv?: Json
          respiratory_rate?: Json
          temperature?: Json
          ecg?: Json
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          date?: string
          heart_rate?: Json
          sleep?: Json
          oxygen_saturation?: Json
          hrv?: Json
          respiratory_rate?: Json
          temperature?: Json
          ecg?: Json
          created_at?: string
        }
      }
      user_devices: {
        Row: {
          id: string
          user_id: string
          device_id: string
          device_version: string
          type: 'TRACKER' | 'SCALE'
          battery: 'High' | 'Medium' | 'Low' | 'Empty'
          battery_level: number
          last_sync_time: string
          mac: string
          features: Json
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          device_id: string
          device_version?: string
          type?: 'TRACKER' | 'SCALE'
          battery?: 'High' | 'Medium' | 'Low' | 'Empty'
          battery_level?: number
          last_sync_time?: string
          mac?: string
          features?: Json
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          device_id?: string
          device_version?: string
          type?: 'TRACKER' | 'SCALE'
          battery?: 'High' | 'Medium' | 'Low' | 'Empty'
          battery_level?: number
          last_sync_time?: string
          mac?: string
          features?: Json
          created_at?: string
          updated_at?: string
        }
      }
      user_profiles: {
        Row: {
          id: string
          user_id: string
          role: 'researcher' | 'participant'
          group: string | null
          participant_id: string | null
          fitbit_access_token: string | null
          fitbit_refresh_token: string | null
          token_expires_at: string | null
          last_sync_at: string | null
          created_at: string
          is_admin: boolean
        }
        Insert: {
          id?: string
          user_id: string
          role: 'researcher' | 'participant'
          group?: string | null
          participant_id?: string | null
          fitbit_access_token?: string | null
          fitbit_refresh_token?: string | null
          token_expires_at?: string | null
          last_sync_at?: string | null
          created_at?: string
          is_admin?: boolean
        }
        Update: {
          id?: string
          user_id?: string
          role?: 'researcher' | 'participant'
          group?: string | null
          participant_id?: string | null
          fitbit_access_token?: string | null
          fitbit_refresh_token?: string | null
          token_expires_at?: string | null
          last_sync_at?: string | null
          created_at?: string
          is_admin?: boolean
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      register_user: {
        Args: {
          p_user_id: string
          p_role: string
          p_participant_id: string
          p_invite_code: string
        }
        Returns: void
      }
    }
    Enums: {
      [_ in never]: never
    }
  }
}