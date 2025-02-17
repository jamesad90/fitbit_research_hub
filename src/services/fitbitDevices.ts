import { supabase } from '../lib/supabase';
import { fetchWithTokenRefresh } from '../lib/fitbit';

export async function syncUserDevices(
  userId: string,
  accessToken: string,
  refreshToken: string,
  tokenExpiresAt: string
) {
  try {
    // First check if user is a participant
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('role')
      .eq('user_id', userId)
      .single();

    if (profileError) {
      throw new Error(`Failed to fetch user profile: ${profileError.message}`);
    }

    // Skip device sync for non-participants
    if (userProfile.role !== 'participant') {
      console.log(`Skipping device sync for non-participant user: ${userId}`);
      return [];
    }

    console.log(`Starting device sync for user: ${userId}`);

    // Fetch devices from Fitbit API
    const response = await fetchWithTokenRefresh(
      userId,
      accessToken,
      refreshToken,
      tokenExpiresAt,
      'https://api.fitbit.com/1/user/-/devices.json'
    );

    if (!response.ok) {
      const responseText = await response.text();
      throw new Error(`Failed to fetch devices: ${response.status} ${response.statusText} - ${responseText}`);
    }

    const devices = await response.json();
    console.log('Raw device data from Fitbit:', devices);

    if (!Array.isArray(devices)) {
      throw new Error(`Invalid device data received from Fitbit API: ${JSON.stringify(devices)}`);
    }

    // Delete existing devices first to ensure clean state
    const { error: deleteError } = await supabase
      .from('user_devices')
      .delete()
      .eq('user_id', userId);

    if (deleteError) {
      throw new Error(`Error deleting existing devices: ${deleteError.message}`);
    }

    // Only proceed with insertion if we have devices
    if (devices.length > 0) {
      const devicesToInsert = devices.map(device => {
        // Validate required fields
        if (!device.id) {
          console.warn('Device missing ID:', device);
          return null;
        }

        // Parse battery level
        let batteryLevel = null;
        if (device.batteryLevel !== undefined && device.batteryLevel !== null) {
          batteryLevel = typeof device.batteryLevel === 'string' 
            ? parseInt(device.batteryLevel, 10)
            : typeof device.batteryLevel === 'number'
              ? device.batteryLevel
              : null;

          if (batteryLevel !== null && (isNaN(batteryLevel) || batteryLevel < 0 || batteryLevel > 100)) {
            console.warn(`Invalid battery level for device ${device.id}:`, device.batteryLevel);
            batteryLevel = null;
          }
        }

        // Map battery status
        let batteryStatus = 'Empty';
        if (device.battery) {
          const status = device.battery.toLowerCase();
          if (status === 'high' || status === 'full') batteryStatus = 'High';
          else if (status === 'medium') batteryStatus = 'Medium';
          else if (status === 'low') batteryStatus = 'Low';
        } else if (batteryLevel !== null) {
          batteryStatus = getBatteryStatus(batteryLevel);
        }

        // Prepare device data
        const deviceData = {
          user_id: userId,
          device_id: device.id,
          device_version: device.deviceVersion || null,
          type: device.type?.toUpperCase() === 'SCALE' ? 'SCALE' : 'TRACKER',
          battery: batteryStatus,
          battery_level: batteryLevel,
          last_sync_time: device.lastSyncTime ? new Date(device.lastSyncTime).toISOString() : null,
          mac: device.mac || null,
          features: Array.isArray(device.features) ? device.features : []
        };

        console.log(`Prepared data for device ${device.id}:`, deviceData);
        return deviceData;
      }).filter(Boolean); // Remove any null entries

      if (devicesToInsert.length === 0) {
        console.log('No valid devices to insert after filtering');
        return [];
      }

      console.log('Devices to insert:', devicesToInsert);

      const { data: insertedDevices, error: insertError } = await supabase
        .from('user_devices')
        .insert(devicesToInsert)
        .select();

      if (insertError) {
        throw new Error(`Error inserting devices: ${insertError.message}`);
      }

      console.log(`Successfully inserted ${insertedDevices.length} devices for user ${userId}`);
      return insertedDevices;
    }

    console.log(`No devices found for user ${userId}`);
    return [];
  } catch (error) {
    console.error(`Error in syncUserDevices for user ${userId}:`, error);
    throw error;
  }
}

function getBatteryStatus(batteryLevel: number): 'High' | 'Medium' | 'Low' | 'Empty' {
  if (batteryLevel >= 75) return 'High';
  if (batteryLevel >= 50) return 'Medium';
  if (batteryLevel >= 25) return 'Low';
  return 'Empty';
}

export async function fetchUserDevices(userId: string) {
  try {
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('role')
      .eq('user_id', userId)
      .single();

    if (profileError) {
      throw new Error(`Failed to fetch user profile: ${profileError.message}`);
    }

    if (userProfile.role !== 'participant') {
      return [];
    }

    const { data, error } = await supabase
      .from('user_devices')
      .select('*')
      .eq('user_id', userId);

    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching devices:', error);
    throw error;
  }
}