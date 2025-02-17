import { supabase } from '../lib/supabase';
import { syncFitbitData } from './fitbitSync';
import { fetchWithTokenRefresh } from '../lib/fitbit';

// Subscription types that we want to monitor
const SUBSCRIPTION_TYPES = [
  'activities/heart',
  'sleep',
  'hrv',
  'spo2',
  'breathing_rate',
  'temperature/core',
  'ecg'
];

export async function setupFitbitSubscriptions(userId: string, accessToken: string, refreshToken: string, tokenExpiresAt: string) {
  try {
    // Get existing subscriptions
    const existingSubscriptions = await listSubscriptions(userId, accessToken, refreshToken, tokenExpiresAt);
    
    // Create missing subscriptions
    for (const type of SUBSCRIPTION_TYPES) {
      if (!existingSubscriptions.some(sub => sub.collectionType === type)) {
        await createSubscription(userId, type, accessToken, refreshToken, tokenExpiresAt);
      }
    }

    return true;
  } catch (error) {
    console.error('Error setting up Fitbit subscriptions:', error);
    return false;
  }
}

async function listSubscriptions(
  userId: string,
  accessToken: string,
  refreshToken: string,
  tokenExpiresAt: string
): Promise<any[]> {
  const response = await fetchWithTokenRefresh(
    userId,
    accessToken,
    refreshToken,
    tokenExpiresAt,
    'https://api.fitbit.com/1/user/-/apiSubscriptions.json'
  );

  if (!response.ok) {
    throw new Error('Failed to list subscriptions');
  }

  const data = await response.json();
  return data.apiSubscriptions || [];
}

async function createSubscription(
  userId: string,
  type: string,
  accessToken: string,
  refreshToken: string,
  tokenExpiresAt: string
): Promise<void> {
  const subscriptionId = `${userId}-${type}`;
  
  const response = await fetchWithTokenRefresh(
    userId,
    accessToken,
    refreshToken,
    tokenExpiresAt,
    `https://api.fitbit.com/1/user/-/${type}/apiSubscriptions/${subscriptionId}.json`,
    {
      method: 'POST',
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to create subscription for ${type}`);
  }
}

// Handle incoming notifications from Fitbit
export async function handleFitbitNotification(notification: any) {
  try {
    const { collectionType, date, ownerId, subscriptionId } = notification;

    // Get user profile from the subscription ID
    const userId = subscriptionId.split('-')[0];
    
    const { data: userProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (profileError || !userProfile) {
      throw new Error('User profile not found');
    }

    // Sync the data for this specific date
    await syncFitbitData(async (endpoint: string) => {
      return fetchWithTokenRefresh(
        userId,
        userProfile.fitbit_access_token,
        userProfile.fitbit_refresh_token,
        userProfile.token_expires_at,
        `https://api.fitbit.com${endpoint}`
      );
    });

    return true;
  } catch (error) {
    console.error('Error handling Fitbit notification:', error);
    return false;
  }
}