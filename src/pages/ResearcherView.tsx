import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { format } from 'date-fns';
import Papa from 'papaparse';
import { RefreshCw, Users, BarChart3, KeyRound } from 'lucide-react';
import UserManagement from '../components/researcher/UserManagement';
import DataVisualization from '../components/researcher/DataVisualization';
import GroupManagement from '../components/researcher/GroupManagement';
import { syncAllParticipants } from '../services/fitbitSync';
import { syncUserDevices } from '../services/fitbitDevices';
import type { UserProfile } from '../types/researcher';

export default function ResearcherView() {
  const [participants, setParticipants] = useState<UserProfile[]>([]);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [disconnecting, setDisconnecting] = useState<string | null>(null);
  const [newCode, setNewCode] = useState('');
  const [participantId, setParticipantId] = useState('');
  const [codeRole, setCodeRole] = useState('participant');
  const [expiryDays, setExpiryDays] = useState(7);
  const [codes, setCodes] = useState<any[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'users' | 'data' | 'codes'>('users');
  const [selectedMetric, setSelectedMetric] = useState('heart_rate');
  const [sampling, setSampling] = useState('daily');
  const [selectedUsers, setSelectedUsers] = useState<string[]>([]);
  const [newGroup, setNewGroup] = useState('');
  const [dataLoading, setDataLoading] = useState(false);
  const [timeseriesData, setTimeseriesData] = useState<DataPoint[]>([]);
  const [groupStats, setGroupStats] = useState<GroupStats[]>([]);
  useEffect(() => {
    const fetchInitialData = async () => {
      try {
        setError(null);
        const { data: profiles, error: profileError } = await supabase
          .from('user_profiles')
          .select(`
            *,
            devices:user_devices(*)
          `)
          .order('created_at', { ascending: false });

        if (profileError) throw profileError;
        setParticipants(profiles || []);

        const { data: inviteCodes, error: codesError } = await supabase
          .from('invitation_codes')
          .select('*')
          .order('created_at', { ascending: false });

        if (codesError) throw codesError;
        setCodes(inviteCodes || []);
      } catch (err: any) {
        console.error('Error fetching initial data:', err);
        setError(err.message || 'Failed to fetch initial data');
      }
    };

    fetchInitialData();
    const interval = setInterval(fetchInitialData, 30000); // Refresh every 30 seconds

    return () => clearInterval(interval);
  }, []);



const fetchVisualizationData = async () => {
  setDataLoading(true);
  try {
    // Get data for selected users
    const { data, error } = await supabase
      .from('fitbit_data')
      .select(`
        date,
        user_id,
        heart_rate,
        sleep,
        hrv,
        oxygen_saturation,
        respiratory_rate,
        user_profiles (
          group_name,
          participant_id
        )
      `)
      .in('user_id', selectedUsers);

    if (error) throw error;

    // Process the data based on selected metric
    const processedData = data.reduce((acc: any[], record: any) => {
      let value = null;
      
      switch (selectedMetric) {
        case 'heart_rate':
          value = record.heart_rate?.average;
          break;
        case 'sleep':
          value = record.sleep?.duration ? record.sleep.duration / 3600000 : null; // Convert to hours
          break;
        case 'hrv':
          value = record.hrv?.daily_rmssd;
          break;
        case 'oxygen_saturation':
          value = record.oxygen_saturation?.average;
          break;
        case 'respiratory_rate':
          value = record.respiratory_rate?.average;
          break;
      }

      const existingDate = acc.find(d => d.date === record.date);
      if (existingDate) {
        existingDate.values = {
          ...existingDate.values,
          [record.user_id]: value
        };
      } else {
        acc.push({
          date: record.date,
          values: {
            [record.user_id]: value
          }
        });
      }

      return acc;
    }, []);

    setTimeseriesData(processedData.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()));

    // Calculate group statistics
    const groupData = data.reduce((acc: any, record: any) => {
      const group = record.user_profiles.group_name || 'No Group';
      if (!acc[group]) acc[group] = [];
      
      let value = null;
      switch (selectedMetric) {
        case 'heart_rate':
          value = record.heart_rate?.average;
          break;
        case 'sleep':
          value = record.sleep?.duration ? record.sleep.duration / 3600000 : null;
          break;
        case 'hrv':
          value = record.hrv?.daily_rmssd;
          break;
        case 'oxygen_saturation':
          value = record.oxygen_saturation?.average;
          break;
        case 'respiratory_rate':
          value = record.respiratory_rate?.average;
          break;
      }
      
      if (value !== null) acc[group].push(value);
      return acc;
    }, {});

    const stats = Object.entries(groupData).map(([group, values]: [string, number[]]) => ({
      group,
      mean: values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0,
      sd: calculateStandardDeviation(values),
      n: values.length
    }));

    setGroupStats(stats);
  } catch (err: any) {
    console.error('Error fetching visualization data:', err);
    setError(err.message || 'Failed to fetch visualization data');
  } finally {
    setDataLoading(false);
  }
};

// Helper function to calculate standard deviation
const calculateStandardDeviation = (values: number[]) => {
  if (values.length === 0) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const squareDiffs = values.map(value => Math.pow(value - mean, 2));
  const avgSquareDiff = squareDiffs.reduce((a, b) => a + b, 0) / values.length;
  return Math.sqrt(avgSquareDiff);
};

  
 const handleSync = async () => {
  setSyncing(true);
  setError(null);
  
  try {
    const { data: activeParticipants, error: fetchError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('role', 'participant')
      .not('fitbit_access_token', 'is', null);

    if (fetchError) throw fetchError;

    if (!activeParticipants || activeParticipants.length === 0) {
      throw new Error('No active participants found with Fitbit connections');
    }

    // Sync devices first and collect results
    const deviceSyncResults = await Promise.allSettled(
      activeParticipants.map(participant => 
        syncUserDevices(
          participant.user_id,
          participant.fitbit_access_token!,
          participant.fitbit_refresh_token!,
          participant.token_expires_at!
        )
      )
    );

    // Log any device sync failures
    deviceSyncResults.forEach((result, index) => {
      if (result.status === 'rejected') {
        console.error(`Error syncing devices for user ${activeParticipants[index].user_id}:`, result.reason);
      }
    });

    // Then sync health data
    const result = await syncAllParticipants(activeParticipants);
    
    if (!result.success) {
      throw new Error(result.error || 'Sync failed');
    }

    // Refresh participant data to get latest device info
    const { data: profiles, error: profileError } = await supabase
      .from('user_profiles')
      .select(`
        *,
        devices:user_devices(*)
      `)
      .order('created_at', { ascending: false });

    if (profileError) throw profileError;
    setParticipants(profiles || []);

    setError(null);
    alert(`Sync completed for ${activeParticipants.length} participants`);
  } catch (err: any) {
    console.error('Error in sync process:', err);
    setError(err.message || 'Failed to sync participant data');
  } finally {
    setSyncing(false);
  }
};


  const disconnectFitbit = async (userId: string) => {
    try {
      setDisconnecting(userId);
      setError(null);

      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({
          fitbit_access_token: null,
          fitbit_refresh_token: null,
          token_expires_at: null
        })
        .eq('user_id', userId);

      if (updateError) throw updateError;
      
      // Refresh participant data
      const { data: profiles, error: profileError } = await supabase
        .from('user_profiles')
        .select(`
          *,
          devices:user_devices(*)
        `)
        .order('created_at', { ascending: false });

      if (profileError) throw profileError;
      setParticipants(profiles || []);
    } catch (err: any) {
      console.error('Error disconnecting Fitbit:', err);
      setError(err.message || 'Failed to disconnect Fitbit');
    } finally {
      setDisconnecting(null);
    }
  };

  const generateCode = async () => {
    try {
      setError(null);
      
      if (!newCode.trim()) {
        setError('Please enter a code');
        return;
      }

      if (!participantId.trim()) {
        setError('Please enter a participant ID');
        return;
      }

      const expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + expiryDays);
      
      const { data, error } = await supabase
        .from('invitation_codes')
        .insert({
          code: newCode.trim(),
          role: codeRole,
          participant_id: participantId.trim(),
          expires_at: expiryDate.toISOString(),
        })
        .select()
        .single();

      if (error) {
        console.error('Error generating code:', error);
        throw error;
      }

      setNewCode('');
      setParticipantId('');

      // Refresh codes
      const { data: inviteCodes, error: codesError } = await supabase
        .from('invitation_codes')
        .select('*')
        .order('created_at', { ascending: false });

      if (codesError) throw codesError;
      setCodes(inviteCodes || []);
    } catch (err: any) {
      console.error('Error generating code:', err);
      setError(err.message || 'Failed to generate invitation code');
    }
  };

  const exportData = async () => {
    if (!startDate || !endDate) {
      alert('Please select both start and end dates');
      return;
    }

    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('fitbit_data')
        .select('*, user_profiles!inner(*)')
        .gte('date', startDate)
        .lte('date', endDate);

      if (error) throw error;

      if (!data || data.length === 0) {
        alert('No data found for the selected date range');
        return;
      }

      const flattenedData = data.map(record => ({
        user_id: record.user_id,
        participant_id: record.user_profiles.participant_id,
        date: record.date,
        heart_rate_avg: record.heart_rate?.average,
        sleep_duration: record.sleep?.duration,
        oxygen_saturation_avg: record.oxygen_saturation?.average,
        hrv_daily: record.hrv?.daily_rmssd,
        respiratory_rate: record.respiratory_rate?.average,
        temperature: record.temperature?.average,
      }));

      const csv = Papa.unparse(flattenedData);
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `fitbit-data-${startDate}-to-${endDate}.csv`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err: any) {
      console.error('Error exporting data:', err);
      setError(err.message || 'Failed to export data');
    } finally {
      setLoading(false);
    }
  };

  const handleUserSelectionChange = (userId: string, selected: boolean) => {
    setSelectedUsers(prev => 
      selected 
        ? [...prev, userId]
        : prev.filter(id => id !== userId)
    );
  };

  const handleAddGroup = async () => {
    if (!newGroup || selectedUsers.length === 0) return;

    try {
      const { error } = await supabase
        .from('user_profiles')
        .update({ group_name: newGroup })
        .in('user_id', selectedUsers);

      if (error) throw error;

      // Refresh participant data
      const { data: profiles, error: profileError } = await supabase
        .from('user_profiles')
        .select(`
          *,
          devices:user_devices(*)
        `)
        .order('created_at', { ascending: false });

      if (profileError) throw profileError;
      setParticipants(profiles || []);

      // Reset selection
      setNewGroup('');
      setSelectedUsers([]);
    } catch (err: any) {
      console.error('Error adding group:', err);
      setError(err.message || 'Failed to add group');
    }
  };

  const metricOptions = [
    { value: 'heart_rate', label: 'Heart Rate' },
    { value: 'sleep', label: 'Sleep Duration' },
    { value: 'hrv', label: 'Heart Rate Variability' },
    { value: 'oxygen_saturation', label: 'Oxygen Saturation' },
    { value: 'respiratory_rate', label: 'Respiratory Rate' }
  ];

  const samplingOptions = [
    { value: 'daily', label: 'Daily' },
    { value: 'weekly', label: 'Weekly' },
    { value: 'monthly', label: 'Monthly' }
  ];

  return (
    <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div className="px-4 py-6 sm:px-0">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-2xl font-semibold text-gray-900">Researcher Dashboard</h1>
          <button
            onClick={handleSync}
            disabled={syncing}
            className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${syncing ? 'animate-spin' : ''}`} />
            {syncing ? 'Syncing Data...' : 'Sync All Data'}
          </button>
        </div>

        {error && (
          <div className="mb-8 bg-red-50 border border-red-400 text-red-700 px-4 py-3 rounded relative">
            <span className="block sm:inline">{error}</span>
          </div>
        )}

        {/* Tabs */}
        <div className="border-b border-gray-200 mb-8">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab('users')}
              className={`${
                activeTab === 'users'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm inline-flex items-center`}
            >
              <Users className="w-5 h-5 mr-2" />
              Users
            </button>
            <button
              onClick={() => setActiveTab('data')}
              className={`${
                activeTab === 'data'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm inline-flex items-center`}
            >
              <BarChart3 className="w-5 h-5 mr-2" />
              Data
            </button>
            <button
              onClick={() => setActiveTab('codes')}
              className={`${
                activeTab === 'codes'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm inline-flex items-center`}
            >
              <KeyRound className="w-5 h-5 mr-2" />
              Invitation Codes
            </button>
          </nav>
        </div>

        {/* Tab Content */}
        {activeTab === 'users' && (
          <>
            <UserManagement
              participants={participants}
              disconnecting={disconnecting}
              onDisconnectFitbit={disconnectFitbit}
            />
            <GroupManagement
              newGroup={newGroup}
              selectedUsers={selectedUsers}
              participants={participants}
              onNewGroupChange={setNewGroup}
              onUserSelectionChange={handleUserSelectionChange}
              onAddGroup={handleAddGroup}
            />
          </>
        )}

        {activeTab === 'data' && (
          <DataVisualization
            selectedMetric={selectedMetric}
            sampling={sampling}
            timeseriesData={timeseriesData}
            groupStats={groupStats}
            metricOptions={metricOptions}
            samplingOptions={samplingOptions}
            participants={participants}
            selectedUsers={selectedUsers}
            onMetricChange={setSelectedMetric}
            onSamplingChange={setSampling}
            onUserSelectionChange={handleUserSelectionChange}
            onUpdateChart={fetchVisualizationData}
            dataLoading={dataLoading}
          />
        )}

        {activeTab === 'codes' && (
          <div className="mt-8 bg-white shadow overflow-hidden sm:rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Invitation Codes</h2>
              
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-4">
                <div>
                  <label htmlFor="new-code" className="block text-sm font-medium text-gray-700">
                    New Code
                  </label>
                  <input
                    type="text"
                    id="new-code"
                    value={newCode}
                    onChange={(e) => setNewCode(e.target.value)}
                    className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                  />
                </div>

                <div>
                  <label htmlFor="participant-id" className="block text-sm font-medium text-gray-700">
                    Participant ID
                  </label>
                  <input
                    type="text"
                    id="participant-id"
                    value={participantId}
                    onChange={(e) => setParticipantId(e.target.value)}
                    className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                    placeholder="e.g., P001"
                  />
                </div>
                
                <div>
                  <label htmlFor="code-role" className="block text-sm font-medium text-gray-700">
                    Role
                  </label>
                  <select
                    id="code-role"
                    value={codeRole}
                    onChange={(e) => setCodeRole(e.target.value)}
                    className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                  >
                    <option value="participant">Participant</option>
                    <option value="researcher">Researcher</option>
                  </select>
                </div>

                <div>
                  <label htmlFor="expiry-days" className="block text-sm font-medium text-gray-700">
                    Expires In (Days)
                  </label>
                  <input
                    type="number"
                    id="expiry-days"
                    value={expiryDays}
                    onChange={(e) => setExpiryDays(parseInt(e.target.value))}
                    min="1"
                    className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                  />
                </div>
              </div>

              <div className="mt-4">
                <button
                  onClick={generateCode}
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Generate Code
                </button>
              </div>

              <div className="mt-6">
                <h3 className="text-sm font-medium text-gray-700 mb-2">Existing Codes</h3>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Code
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Participant ID
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Role
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Status
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Used By
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Used At
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Expires
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {codes.map((code) => (
                        <tr key={code.code}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {code.code}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {code.participant_id || '-'}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {code.role}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {code.used_at ? (
                              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                                Used
                              </span>
                            ) : new Date(code.expires_at) < new Date() ? (
                              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                                Expired
                              </span>
                            ) : (
                              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                Available
                              </span>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {code.used_by || '-'}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {code.used_at ? format(new Date(code.used_at), 'PPP p') : '-'}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {format(new Date(code.expires_at), 'PPP')}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Export Data Section */}
        <div className="mt-8 bg-white shadow overflow-hidden sm:rounded-lg">
          <div className="px-4 py-5 sm:p-6">
            <h2 className="text-lg font-medium text-gray-900">Export Data</h2>
            
            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div>
                <label htmlFor="start-date" className="block text-sm font-medium text-gray-700">
                  Start Date
                </label>
                <input
                  type="date"
                  id="start-date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                />
              </div>
              
              <div>
                <label htmlFor="end-date" className="block text-sm font-medium text-gray-700">
                  End Date
                </label>
                <input
                  type="date"
                  id="end-date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm p-2"
                />
              </div>
              
              <div className="flex items-end">
                <button
                  onClick={exportData}
                  disabled={loading}
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
                >
                  {loading ? 'Exporting...' : 'Export CSV'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}