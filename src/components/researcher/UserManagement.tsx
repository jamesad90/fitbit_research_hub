import React, { useState } from 'react';
import { UserX, Battery, Watch } from 'lucide-react';
import type { UserProfile } from '../../types/researcher';
import { format } from 'date-fns';

interface Props {
  participants: UserProfile[];
  disconnecting: string | null;
  onDisconnectFitbit: (userId: string) => void;
}

export default function UserManagement({ participants, disconnecting, onDisconnectFitbit }: Props) {
  const [sortConfig, setSortConfig] = useState<{ key: string; direction: 'asc' | 'desc' } | null>(null);

  const sortData = (key: string) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const getSortedData = (data: UserProfile[]) => {
    if (!sortConfig) return data;

    return [...data].sort((a, b) => {
      let aValue = a[sortConfig.key as keyof UserProfile];
      let bValue = b[sortConfig.key as keyof UserProfile];

      // Handle nested properties
      if (sortConfig.key === 'last_sync') {
        aValue = a.last_sync_at ? new Date(a.last_sync_at).getTime() : 0;
        bValue = b.last_sync_at ? new Date(b.last_sync_at).getTime() : 0;
      }

      if (aValue < bValue) {
        return sortConfig.direction === 'asc' ? -1 : 1;
      }
      if (aValue > bValue) {
        return sortConfig.direction === 'asc' ? 1 : -1;
      }
      return 0;
    });
  };

  return (
    <div className="mb-8 bg-white shadow overflow-hidden sm:rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">User Management</h2>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                {[
                  'ID',
                  'User ID',
                  'Role',
                  'Device Info',
                  'Battery',
                  'Last Sync',
                  'Created At',
                  'Fitbit Status',
                  'Actions'
                ].map((header) => (
                  <th
                    key={header}
                    onClick={() => sortData(header.toLowerCase().replace(/ /g, '_'))}
                    className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                  >
                    {header}
                    {sortConfig?.key === header.toLowerCase().replace(/ /g, '_') && (
                      <span className="ml-1">
                        {sortConfig.direction === 'asc' ? '↑' : '↓'}
                      </span>
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {getSortedData(participants).map((user) => (
                <tr key={user.user_id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {user.participant_id || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.user_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      user.role === 'researcher' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'
                    }`}>
                      {user.role}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.devices?.map((device, index) => (
                      <div key={device.device_id} className={index > 0 ? 'mt-2' : ''}>
                        <div className="flex items-center">
                          <Watch className="w-4 h-4 mr-1" />
                          <span>{device.device_version}</span>
                        </div>
                        <div className="text-xs text-gray-400">
                          ID: {device.device_id}
                        </div>
                      </div>
                    )) || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.devices?.map((device, index) => (
                      <div key={device.device_id} className={index > 0 ? 'mt-2' : ''}>
                        <div className="flex items-center">
                          <Battery className={`w-4 h-4 mr-1 ${
                            device.battery_level >= 75 ? 'text-green-500' :
                            device.battery_level >= 50 ? 'text-yellow-500' :
                            device.battery_level >= 25 ? 'text-orange-500' :
                            'text-red-500'
                          }`} />
                          <span>{device.battery_level}%</span>
                        </div>
                        <div className="text-xs text-gray-400">
                          {device.battery}
                        </div>
                      </div>
                    )) || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.last_sync_at ? format(new Date(user.last_sync_at), 'PPP p') : 'Never'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format(new Date(user.created_at), 'PPP')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.role === 'participant' ? (
                      user.fitbit_access_token ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Connected
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          Not Connected
                        </span>
                      )
                    ) : (
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        N/A
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.role === 'participant' && user.fitbit_access_token && (
                      <button
                        onClick={() => onDisconnectFitbit(user.user_id)}
                        disabled={disconnecting === user.user_id}
                        className="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                      >
                        <UserX className="w-4 h-4 mr-1" />
                        {disconnecting === user.user_id ? 'Disconnecting...' : 'Disconnect Fitbit'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}