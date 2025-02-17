import { useAuth } from '../contexts/AuthContext';
import { fetchWithTokenRefresh } from '../lib/fitbit';

export function useFitbit() {
  const { user, userProfile } = useAuth();

  const fetchFitbitData = async (endpoint: string, options: RequestInit = {}) => {
    if (!user || !userProfile?.fitbit_access_token || !userProfile?.fitbit_refresh_token || !userProfile?.token_expires_at) {
      throw new Error('No Fitbit credentials available');
    }

    const baseUrl = 'https://api.fitbit.com';
    const url = `${baseUrl}${endpoint}`;

    return fetchWithTokenRefresh(
      user.id,
      userProfile.fitbit_access_token,
      userProfile.fitbit_refresh_token,
      userProfile.token_expires_at,
      url,
      options
    );
  };

  return { fetchFitbitData };
}