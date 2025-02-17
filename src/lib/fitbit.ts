import { supabase } from './supabase';

interface FitbitTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

export async function refreshFitbitToken(userId: string, refreshToken: string): Promise<FitbitTokens | null> {
  try {
    const response = await fetch('https://api.fitbit.com/oauth2/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${btoa(`${import.meta.env.VITE_FITBIT_CLIENT_ID}:${import.meta.env.VITE_FITBIT_CLIENT_SECRET}`)}`,
      },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to refresh token');
    }

    const data = await response.json();

    // Update tokens in database
    const { error: updateError } = await supabase
      .from('user_profiles')
      .update({
        fitbit_access_token: data.access_token,
        fitbit_refresh_token: data.refresh_token,
        token_expires_at: new Date(Date.now() + data.expires_in * 1000).toISOString(),
      })
      .eq('user_id', userId);

    if (updateError) {
      throw updateError;
    }

    return data;
  } catch (error) {
    console.error('Error refreshing Fitbit token:', error);
    return null;
  }
}

export async function fetchWithTokenRefresh(
  userId: string,
  accessToken: string,
  refreshToken: string,
  expiresAt: string,
  url: string,
  options: RequestInit = {}
): Promise<Response> {
  // Check if token is expired or will expire in the next minute
  const isExpired = new Date(expiresAt).getTime() - 60000 < Date.now();

  // If token is expired, refresh it
  if (isExpired) {
    const newTokens = await refreshFitbitToken(userId, refreshToken);
    if (!newTokens) {
      throw new Error('Failed to refresh token');
    }
    accessToken = newTokens.access_token;
  }

  // Add authorization header
  const headers = new Headers(options.headers);
  headers.set('Authorization', `Bearer ${accessToken}`);

  // Make the request
  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    // Token might be invalid, try refreshing
    const newTokens = await refreshFitbitToken(userId, refreshToken);
    if (!newTokens) {
      throw new Error('Failed to refresh token after 401');
    }

    // Retry the request with new token
    headers.set('Authorization', `Bearer ${newTokens.access_token}`);
    return fetch(url, {
      ...options,
      headers,
    });
  }

  return response;
}