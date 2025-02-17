import React, { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { syncAllParticipants } from '../services/fitbitSync';

export default function FitbitCallback() {
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const location = useLocation();
  const { user, loading } = useAuth();

  useEffect(() => {
    const handleCallback = async () => {
      // Wait for auth state to be initialized
      if (loading) return;

      if (!user) {
        setError('User not authenticated. Please sign in and try again.');
        setTimeout(() => {
          navigate('/login', { replace: true });
        }, 3000);
        return;
      }

      const params = new URLSearchParams(location.search);
      const code = params.get('code');

      if (!code) {
        setError('No authorization code received');
        return;
      }

      try {
        // Exchange code for token
        const response = await fetch('https://api.fitbit.com/oauth2/token', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${btoa(`${import.meta.env.VITE_FITBIT_CLIENT_ID}:${import.meta.env.VITE_FITBIT_CLIENT_SECRET}`)}`,
          },
          body: new URLSearchParams({
            code,
            grant_type: 'authorization_code',
            redirect_uri: import.meta.env.VITE_FITBIT_REDIRECT_URI,
          }),
        });

        const data = await response.json();

        if (!response.ok) {
          console.error('Fitbit token exchange error:', data);
          throw new Error(data.errors?.[0]?.message || 'Failed to exchange code for token');
        }

        const tokenExpiresAt = new Date(Date.now() + data.expires_in * 1000).toISOString();

        // Update user profile with Fitbit tokens
        const { error: updateError } = await supabase
          .from('user_profiles')
          .update({
            fitbit_access_token: data.access_token,
            fitbit_refresh_token: data.refresh_token,
            token_expires_at: tokenExpiresAt,
          })
          .eq('user_id', user.id);

        if (updateError) throw updateError;

        // Perform initial sync
        await syncAllParticipants([{
          user_id: user.id,
          fitbit_access_token: data.access_token,
          fitbit_refresh_token: data.refresh_token,
          token_expires_at: tokenExpiresAt
        }]);

        // Get the stored redirect URL or default to dashboard
        const redirectUrl = sessionStorage.getItem('fitbitRedirectUrl') || '/dashboard';
        sessionStorage.removeItem('fitbitRedirectUrl');

        navigate(redirectUrl, { replace: true });
      } catch (err: any) {
        console.error('Error in Fitbit callback:', err);
        setError('Failed to connect Fitbit account. Please try again.');
        setTimeout(() => {
          navigate('/dashboard', { replace: true });
        }, 3000);
      }
    };

    handleCallback();
  }, [location.search, user, loading, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-pulse flex flex-col items-center">
          <div className="h-8 w-8 bg-indigo-600 rounded-full mb-4"></div>
          <div className="text-xl text-gray-600">
            Connecting your Fitbit account...
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded relative">
          <span className="block sm:inline">{error}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="animate-pulse flex flex-col items-center">
        <div className="h-8 w-8 bg-indigo-600 rounded-full mb-4"></div>
        <div className="text-xl text-gray-600">
          Connecting your Fitbit account...
        </div>
      </div>
    </div>
  );
}