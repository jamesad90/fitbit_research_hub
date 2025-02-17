import React from 'react';
import type { UserProfile } from '../../types/researcher';
import { format } from 'date-fns';

interface Props {
  newGroup: string;
  selectedUsers: string[];
  participants: UserProfile[];
  onNewGroupChange: (group: string) => void;
  onUserSelectionChange: (userId: string, selected: boolean) => void;
  onAddGroup: () => void;
}

export default function GroupManagement({
  newGroup,
  selectedUsers,
  participants,
  onNewGroupChange,
  onUserSelectionChange,
  onAddGroup
}: Props) {
  // Filter out researchers, only show participants
  const participantsOnly = participants.filter(user => user.role === 'participant');

  return (
    <div className="mb-8 bg-white shadow overflow-hidden sm:rounded-lg">
      <div className="px-4 py-5 sm:p-6">
        <h2 className="text-lg font-medium text-gray-900 mb-4">Group Management</h2>
        
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-700">New Group Name</label>
            <input
              type="text"
              value={newGroup}
              onChange={(e) => onNewGroupChange(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              placeholder="e.g., Control, Intervention"
            />
          </div>

          <div className="flex items-end">
            <button
              onClick={onAddGroup}
              disabled={!newGroup.trim() || selectedUsers.length === 0}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
            >
              Add to Group
            </button>
          </div>
        </div>

        {/* User Selection Table */}
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Select
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Participant ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Current Group
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Created At
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {participantsOnly.map((user) => (
                <tr key={user.user_id}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <input
                      type="checkbox"
                      checked={selectedUsers.includes(user.user_id)}
                      onChange={(e) => onUserSelectionChange(user.user_id, e.target.checked)}
                      className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                    />
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {user.participant_id || user.user_id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {user.group_name || 'None'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {format(new Date(user.created_at), 'PPP')}
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