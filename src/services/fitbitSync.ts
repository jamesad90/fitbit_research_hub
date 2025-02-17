import { supabase } from '../lib/supabase';
import { fetchWithTokenRefresh } from '../lib/fitbit';
import { format, subDays } from 'date-fns';

async function syncUserData(
  userId: string,
  date: Date,
  accessToken: string,
  refreshToken: string,
  tokenExpiresAt: string
) {
  try {
    const dateStr = format(date, 'yyyy-MM-dd');
    const baseUrl = 'https://api.fitbit.com';

    // Fetch heart rate data
    const heartRateResponse = await fetchWithTokenRefresh(
      userId,
      accessToken,
      refreshToken,
      tokenExpiresAt,
      `${baseUrl}/1/user/-/activities/heart/date/${dateStr}/1d.json`
    );

    if (!heartRateResponse.ok) {
      throw new Error(`Failed to fetch heart rate data: ${heartRateResponse.status}`);
    }

    const heartRateData = await heartRateResponse.json();

    // Fetch sleep data
    const sleepResponse = await fetchWithTokenRefresh(
      userId,
      accessToken,
      refreshToken,
      tokenExpiresAt,
      `${baseUrl}/1.2/user/-/sleep/date/${dateStr}.json`
    );

    if (!sleepResponse.ok) {
      throw new Error(`Failed to fetch sleep data: ${sleepResponse.status}`);
    }

    const sleepData = await sleepResponse.json();

    // Process the data
    const heartRate = heartRateData['activities-heart']?.[0]?.value ? {
      zones: heartRateData['activities-heart'][0].value.heartRateZones,
      restingHeartRate: heartRateData['activities-heart'][0].value.restingHeartRate,
      average: calculateAverageHeartRate(heartRateData['activities-heart'][0].value.heartRateZones)
    } : null;

    const mainSleep = sleepData.sleep?.find((s: any) => s.isMainSleep) || sleepData.sleep?.[0];
    const sleep = mainSleep ? {
      duration: mainSleep.duration,
      efficiency: mainSleep.efficiency,
      stages: mainSleep.levels.summary,
      minuteData: mainSleep.levels.data
    } : null;

    // Upsert the data
    const { error: upsertError } = await supabase
      .from('fitbit_data')
      .upsert({
        date: dateStr,
        user_id: userId,
        heart_rate: heartRate,
        sleep,
        hrv: null,
        oxygen_saturation: null,
        respiratory_rate: null,
        temperature: null,
        ecg: null
      }, {
        onConflict: 'user_id,date'
      });

    if (upsertError) {
      throw upsertError;
    }

    return true;
  } catch (error) {
    console.error(`Error syncing data for user ${userId}:`, error);
    return false;
  }
}

export async function syncAllParticipants(participants: any[]) {
  try {
    // Get date range for the last week
    const endDate = new Date();
    const startDate = subDays(endDate, 7);
    const dates = getDatesInRange(startDate, endDate);
    const results = [];

    for (const p of participants) {
      const userResults = [];
      for (const date of dates) {
        try {
          const success = await syncUserData(
            p.user_id,
            date,
            p.fitbit_access_token,
            p.fitbit_refresh_token,
            p.token_expires_at
          );

          userResults.push({ date: format(date, 'yyyy-MM-dd'), success });

          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 250));
        } catch (error) {
          console.error(`Error syncing user ${p.user_id} for date ${format(date, 'yyyy-MM-dd')}:`, error);
          userResults.push({ 
            date: format(date, 'yyyy-MM-dd'), 
            success: false, 
            error: error.message 
          });
        }
      }

      // Update last sync time if at least one date was successful
      if (userResults.some(r => r.success)) {
        await supabase
          .from('user_profiles')
          .update({ last_sync_at: new Date().toISOString() })
          .eq('user_id', p.user_id);
      }

      results.push({
        userId: p.user_id,
        results: userResults
      });
    }

    return { success: true, results };
  } catch (error) {
    console.error('Error in syncAllParticipants:', error);
    return { success: false, error: error.message };
  }
}

function getDatesInRange(start: Date, end: Date): Date[] {
  const dates = [];
  const current = new Date(start);
  
  while (current <= end) {
    dates.push(new Date(current));
    current.setDate(current.getDate() + 1);
  }
  
  return dates;
}

function calculateAverageHeartRate(zones: any[]): number | null {
  if (!zones || zones.length === 0) return null;
  
  let totalMinutes = 0;
  let weightedSum = 0;

  zones.forEach((zone: any) => {
    const minutes = zone.minutes || 0;
    const avgZoneRate = (zone.min + zone.max) / 2;
    weightedSum += minutes * avgZoneRate;
    totalMinutes += minutes;
  });

  return totalMinutes > 0 ? Math.round(weightedSum / totalMinutes) : null;
}