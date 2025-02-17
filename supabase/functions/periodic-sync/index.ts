import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'
import { corsHeaders } from '../_shared/cors.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

async function syncUserData(
  userId: string,
  date: Date,
  accessToken: string,
  refreshToken: string,
  tokenExpiresAt: string
) {
  try {
    const dateStr = formatDate(date);
    const baseUrl = 'https://api.fitbit.com';

    // Fetch heart rate data
    const heartRateResponse = await fetch(
      `${baseUrl}/1/user/-/activities/heart/date/${dateStr}/1d.json`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
    );

    if (!heartRateResponse.ok) {
      if (heartRateResponse.status === 401) {
        // Token expired, refresh it
        const refreshResponse = await fetch('https://api.fitbit.com/oauth2/token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${btoa(`${Deno.env.get('FITBIT_CLIENT_ID')}:${Deno.env.get('FITBIT_CLIENT_SECRET')}`)}`
          },
          body: new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken
          })
        });

        if (!refreshResponse.ok) {
          throw new Error('Failed to refresh token');
        }

        const newTokens = await refreshResponse.json();
        
        // Update tokens in database
        await supabase
          .from('user_profiles')
          .update({
            fitbit_access_token: newTokens.access_token,
            fitbit_refresh_token: newTokens.refresh_token,
            token_expires_at: new Date(Date.now() + newTokens.expires_in * 1000).toISOString()
          })
          .eq('user_id', userId);

        // Retry the sync with new token
        return syncUserData(
          userId,
          date,
          newTokens.access_token,
          newTokens.refresh_token,
          new Date(Date.now() + newTokens.expires_in * 1000).toISOString()
        );
      }
      throw new Error(`Failed to fetch heart rate data: ${heartRateResponse.status}`);
    }

    const heartRateData = await heartRateResponse.json();

    // Fetch sleep data
    const sleepResponse = await fetch(
      `${baseUrl}/1.2/user/-/sleep/date/${dateStr}.json`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      }
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

async function immediateSync(participants: any[]) {
  try {
    // Get date range for the last week
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 7);

    const dates = getDatesInRange(startDate, endDate);
    const results = [];

    for (const p of participants) {
      const userResults = [];
      for (const date of dates) {
        try {
          const success = await syncUserData(
            p.userId,
            date,
            p.accessToken,
            p.refreshToken,
            p.tokenExpiresAt
          );

          userResults.push({ date: formatDate(date), success });

          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 250));
        } catch (error) {
          console.error(`Error syncing user ${p.userId} for date ${formatDate(date)}:`, error);
          userResults.push({ 
            date: formatDate(date), 
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
          .eq('user_id', p.userId);
      }

      results.push({
        userId: p.userId,
        results: userResults
      });
    }

    return { success: true, results };
  } catch (error) {
    console.error('Error in immediateSync:', error);
    return { success: false, error: error.message };
  }
}

function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
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

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { 
      headers: {
        ...corsHeaders,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Max-Age': '86400',
      }
    });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        {
          status: 405,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      );
    }

    const body = await req.json();
    
    if (body.immediate && Array.isArray(body.participants)) {
      // Handle immediate sync request
      const result = await immediateSync(body.participants);
      
      if (!result.success) {
        throw new Error(result.error || 'Sync failed');
      }
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Immediate sync completed',
          results: result.results
        }),
        {
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: 'Invalid request'
      }),
      {
        status: 400,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  } catch (error) {
    console.error('Error in Edge Function:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'An unexpected error occurred' 
      }),
      {
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  }
})