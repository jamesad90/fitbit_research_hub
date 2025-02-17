import React from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Dashboard() {
  const { userProfile, loading } = useAuth();
  const navigate = useNavigate();

  React.useEffect(() => {
    if (!loading) {
      if (userProfile) {
        if (userProfile.role === 'participant') {
          // Only redirect to onboarding if Fitbit is not connected
          if (!userProfile.fitbit_access_token) {
            navigate('/onboarding', { replace: true });
            return;
          }
          // Otherwise, go to participant view
          navigate('/participant', { replace: true });
        } else if (userProfile.role === 'researcher') {
          navigate('/researcher', { replace: true });
        }
      }
    }
  }, [userProfile, loading, navigate]);

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
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center">
          <h2 className="text-3xl font-extrabold text-gray-900 sm:text-4xl">
            Redirecting to your dashboard...
          </h2>
        </div>
      </div>
    </div>
  );
}