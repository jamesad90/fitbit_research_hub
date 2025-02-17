import React, { useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar, ErrorBar } from 'recharts';
import type { GroupStats, DataPoint, UserProfile } from '../../types/researcher';

const COLORS = [
  '#8884d8',
  '#82ca9d',
  '#ffc658',
  '#ff7300',
  '#0088fe',
  '#00c49f',
  '#ffbb28',
  '#ff8042'
];

interface Props {
  selectedMetric: string;
  sampling: string;
  timeseriesData: DataPoint[];
  groupStats: GroupStats[];
  metricOptions: { value: string; label: string; }[];
  samplingOptions: { value: string; label: string; }[];
  participants: UserProfile[];
  selectedUsers: string[];
  onMetricChange: (metric: string) => void;
  onSamplingChange: (sampling: string) => void;
  onUserSelectionChange: (userId: string, selected: boolean) => void;
  onUpdateChart: () => void;
  dataLoading: boolean;
}

export default function DataVisualization({
  selectedMetric,
  sampling,
  timeseriesData,
  groupStats,
  metricOptions,
  samplingOptions,
  participants,
  selectedUsers,
  onMetricChange,
  onSamplingChange,
  onUserSelectionChange,
  onUpdateChart,
  dataLoading
}: Props) {
  const [viewMode, setViewMode] = useState<'individual' | 'group'>('individual');

  // Filter out researchers, only show participants
  const participantsOnly = participants.filter(user => user.role === 'participant');

  return (
    <div className="mb-8 bg-white shadow overflow-hidden sm:rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">Data Visualization</h2>
        
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-4 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-700">Metric</label>
            <select
              value={selectedMetric}
              onChange={(e) => onMetricChange(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            >
              {metricOptions.map(option => (
                <option key={option.value} value={option.value}>{option.label}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">Sampling</label>
            <select
              value={sampling}
              onChange={(e) => onSamplingChange(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            >
              {samplingOptions.map(option => (
                <option key={option.value} value={option.value}>{option.label}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">View Mode</label>
            <select
              value={viewMode}
              onChange={(e) => setViewMode(e.target.value as 'individual' | 'group')}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            >
              <option value="individual">Individual Data</option>
              <option value="group">Group Comparison</option>
            </select>
          </div>

          <div className="flex items-end">
            <button
              onClick={onUpdateChart}
              disabled={dataLoading}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
            >
              {dataLoading ? 'Loading...' : 'Update Chart'}
            </button>
          </div>
        </div>

        {/* Participant Selection */}
        {viewMode === 'individual' && (
          <div className="mb-6">
            <h3 className="text-sm font-medium text-gray-700 mb-2">Select Participants</h3>
            <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-4">
              {participantsOnly.map(participant => (
                <label key={participant.user_id} className="inline-flex items-center">
                  <input
                    type="checkbox"
                    checked={selectedUsers.includes(participant.user_id)}
                    onChange={(e) => onUserSelectionChange(participant.user_id, e.target.checked)}
                    className="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                  />
                  <span className="ml-2 text-sm text-gray-700">
                    {participant.participant_id || participant.user_id}
                  </span>
                </label>
              ))}
            </div>
          </div>
        )}

        {/* Individual Time Series Chart */}
        {viewMode === 'individual' && timeseriesData && timeseriesData.length > 0 && (
          <div className="h-[400px] mb-8">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={timeseriesData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                {selectedUsers.map((userId, index) => {
                  const participant = participantsOnly.find(p => p.user_id === userId);
                  return (
                    <Line
                      key={userId}
                      type="monotone"
                      dataKey={`values.${userId}`}
                      stroke={COLORS[index % COLORS.length]}
                      name={participant?.participant_id || userId}
                      connectNulls
                    />
                  );
                })}
              </LineChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Group Comparison Chart */}
        {viewMode === 'group' && groupStats && groupStats.length > 0 && (
          <div className="h-[400px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={groupStats}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="group" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="mean" fill="#8884d8" name="Mean">
                  <ErrorBar dataKey="sd" width={4} strokeWidth={2} stroke="#666" />
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* No Data Message */}
        {((viewMode === 'individual' && (!timeseriesData || timeseriesData.length === 0)) ||
         (viewMode === 'group' && (!groupStats || groupStats.length === 0))) && (
          <div className="text-center py-12">
            <p className="text-gray-500">No data available for the selected parameters</p>
          </div>
        )}
      </div>
    </div>
  );
}