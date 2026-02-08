import React from 'react';
import { Users, Activity, Trash2 } from 'lucide-react';

interface DeviceGroup {
  id: number;
  name: string;
  description: string;
  color: string;
  online_count: number;
  total_count: number;
  battery_average: number;
  last_activity: string;
}

interface GroupCardProps {
  group: DeviceGroup;
  onClick: () => void;
  onDelete: (id: number) => void;
}

export const GroupCard: React.FC<GroupCardProps> = ({ group, onClick, onDelete }) => {
  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    onDelete(group.id);
  };

  return (
    <div
      className="bg-white dark:bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-shadow cursor-pointer overflow-hidden"
      onClick={onClick}
    >
      <div className="h-3" style={{ backgroundColor: group.color }} />
      
      <div className="p-6">
        <div className="flex items-start justify-between mb-4">
          <div>
            <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-1">
              {group.name}
            </h3>
            <p className="text-sm text-gray-600 dark:text-gray-400">
              {group.description}
            </p>
          </div>
          <button
            onClick={handleDelete}
            className="text-gray-400 hover:text-red-600 transition-colors"
          >
            <Trash2 size={20} />
          </button>
        </div>

        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Users size={18} className="text-blue-600 dark:text-blue-400" />
              <span className="text-sm text-gray-700 dark:text-gray-300">Devices</span>
            </div>
            <span className="font-semibold text-gray-900 dark:text-white">
              {group.total_count}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Activity size={18} className="text-green-600 dark:text-green-400" />
              <span className="text-sm text-gray-700 dark:text-gray-300">Online</span>
            </div>
            <span className="font-semibold text-green-600 dark:text-green-400">
              {group.online_count} / {group.total_count}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-lg">🔋</span>
              <span className="text-sm text-gray-700 dark:text-gray-300">Avg Battery</span>
            </div>
            <span className="font-semibold text-gray-900 dark:text-white">
              {group.battery_average}%
            </span>
          </div>
        </div>

        <div className="mt-4 pt-4 border-t dark:border-gray-700">
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Last activity: {group.last_activity ? new Date(group.last_activity).toLocaleString() : 'N/A'}
          </p>
        </div>
      </div>
    </div>
  );
};
