import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ActivitySquare, Heart, Moon, Watch } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export default function OnboardingFlow() {
  const navigate = useNavigate();
  const { userProfile, user, loading } = useAuth();
  
  const handleConnectFitbit = () => {
    if (!user) {
      console.error('User not authenticated');
      navigate('/login', { replace: true });
      return;
    }

    const clientId = import.meta.env.VITE_FITBIT_CLIENT_ID;
    const redirectUri = import.meta.env.VITE_FITBIT_REDIRECT_URI;
    const scope = 'activity heartrate sleep oxygen_saturation respiratory_rate temperature electrocardiogram settings';
    
    // Store the current URL in session storage
    sessionStorage.setItem('fitbitRedirectUrl', window.location.href);
    
    // Redirect to Fitbit auth page
    window.location.href = `https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=${encodeURIComponent(scope)}`;
  };

  // Redirect to dashboard if already connected
  React.useEffect(() => {
    if (!loading) {
      if (!user) {
        navigate('/login', { replace: true });
        return;
      }

      if (userProfile?.fitbit_access_token) {
        navigate('/dashboard', { replace: true });
      }
    }
  }, [userProfile, user, loading, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-pulse flex flex-col items-center">
          <div className="h-8 w-8 bg-indigo-600 rounded-full mb-4"></div>
          <div className="text-xl text-gray-600">Loading...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 to-white">
      <div className="max-w-4xl mx-auto pt-16 px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <ActivitySquare className="w-16 h-16 text-indigo-600 mx-auto" />
          <h1 className="mt-6 text-4xl font-extrabold text-gray-900 tracking-tight">
            Welcome to Health Dashboard
          </h1>
          <p className="mt-4 text-xl text-gray-500">
            Let's get you set up with your Fitbit device to start tracking your health data.
          </p>
        </div>

        <div className="mt-16">
          <div className="bg-white rounded-lg shadow-xl overflow-hidden">
            <div className="px-6 py-8 sm:p-10">
              <div className="grid grid-cols-1 gap-8 sm:grid-cols-3">
                <div className="text-center">
                  <Heart className="w-12 h-12 text-indigo-500 mx-auto" />
                  <h3 className="mt-4 text-lg font-medium text-gray-900">Heart Rate</h3>
                  <p className="mt-2 text-sm text-gray-500">
                    Track your heart rate patterns throughout the day
                  </p>
                </div>
                <div className="text-center">
                  <Moon className="w-12 h-12 text-indigo-500 mx-auto" />
                  <h3 className="mt-4 text-lg font-medium text-gray-900">Sleep Analysis</h3>
                  <p className="mt-2 text-sm text-gray-500">
                    Monitor your sleep quality and patterns
                  </p>
                </div>
                <div className="text-center">
                  <Watch className="w-12 h-12 text-indigo-500 mx-auto" />
                  <h3 className="mt-4 text-lg font-medium text-gray-900">Activity Tracking</h3>
                  <p className="mt-2 text-sm text-gray-500">
                    Keep track of your daily activities and exercises
                  </p>
                </div>
              </div>

              <div className="mt-10 text-center">
                <button
                  onClick={handleConnectFitbit}
                  className="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Connect Your Fitbit Device
                </button>
                <p className="mt-4 text-sm text-gray-500">
                  You'll be redirected to Fitbit to authorize access to your data
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}