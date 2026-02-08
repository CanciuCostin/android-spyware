import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { GroupCard } from '../../components/fleet/GroupCard';
import { Button } from '../../components/ui/button';
import { Plus, Users, Activity } from 'lucide-react';

interface DeviceGroup {
  id: number;
  name: string;
  description: string;
  color: string;
  online_count: number;
  total_count: number;
  battery_average: number;
  last_activity: string;
  devices: any[];
}

export const FleetDashboard: React.FC = () => {
  const [groups, setGroups] = useState<DeviceGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetchGroups();
  }, []);

  const fetchGroups = async () => {
    try {
      const response = await fetch('/device_groups');
      const data = await response.json();
      setGroups(data);
    } catch (error) {
      console.error('Failed to fetch groups:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateGroup = async (groupData: Partial<DeviceGroup>) => {
    try {
      const response = await fetch('/device_groups', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_group: groupData }),
      });

      if (response.ok) {
        fetchGroups();
        setShowCreateModal(false);
      }
    } catch (error) {
      console.error('Failed to create group:', error);
    }
  };

  const handleDeleteGroup = async (id: number) => {
    if (!confirm('Are you sure you want to delete this group?')) return;

    try {
      const response = await fetch(`/device_groups/${id}`, {
        method: 'DELETE',
      });

      if (response.ok) {
        fetchGroups();
      }
    } catch (error) {
      console.error('Failed to delete group:', error);
    }
  };

  const totalDevices = groups.reduce((sum, g) => sum + g.total_count, 0);
  const totalOnline = groups.reduce((sum, g) => sum + g.online_count, 0);
  const avgBattery = groups.length > 0
    ? groups.reduce((sum, g) => sum + g.battery_average, 0) / groups.length
    : 0;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500" />
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            Fleet Management
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Manage device groups and perform bulk operations
          </p>
        </div>
        <Button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center gap-2"
        >
          <Plus size={20} />
          Create Group
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-blue-100 dark:bg-blue-900 rounded-lg">
              <Users className="text-blue-600 dark:text-blue-400" size={24} />
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Groups</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {groups.length}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-green-100 dark:bg-green-900 rounded-lg">
              <Activity className="text-green-600 dark:text-green-400" size={24} />
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Online Devices</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {totalOnline} / {totalDevices}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <div className="p-3 bg-yellow-100 dark:bg-yellow-900 rounded-lg">
              <span className="text-yellow-600 dark:text-yellow-400 text-xl">🔋</span>
            </div>
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Avg Battery</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {avgBattery.toFixed(1)}%
              </p>
            </div>
          </div>
        </div>
      </div>

      {groups.length === 0 ? (
        <div className="text-center py-12 bg-white dark:bg-gray-800 rounded-lg shadow">
          <Users size={48} className="mx-auto text-gray-400 mb-4" />
          <h3 className="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-2">
            No Groups Yet
          </h3>
          <p className="text-gray-500 dark:text-gray-400 mb-4">
            Create your first device group to get started
          </p>
          <Button onClick={() => setShowCreateModal(true)}>
            Create Your First Group
          </Button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {groups.map((group) => (
            <GroupCard
              key={group.id}
              group={group}
              onDelete={handleDeleteGroup}
              onClick={() => navigate(`/fleet/${group.id}`)}
            />
          ))}
        </div>
      )}

      {showCreateModal && (
        <CreateGroupModal
          onClose={() => setShowCreateModal(false)}
          onCreate={handleCreateGroup}
        />
      )}
    </div>
  );
};

const CreateGroupModal: React.FC<{
  onClose: () => void;
  onCreate: (data: Partial<DeviceGroup>) => void;
}> = ({ onClose, onCreate }) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [color, setColor] = useState('#3B82F6');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onCreate({ name, description, color });
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-6 w-full max-w-md">
        <h2 className="text-2xl font-bold mb-4 text-gray-900 dark:text-white">
          Create Device Group
        </h2>
        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Group Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
              required
            />
          </div>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600"
              rows={3}
            />
          </div>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Color
            </label>
            <input
              type="color"
              value={color}
              onChange={(e) => setColor(e.target.value)}
              className="w-full h-10 rounded cursor-pointer"
            />
          </div>
          <div className="flex gap-3">
            <Button type="submit" className="flex-1">
              Create
            </Button>
            <Button type="button" onClick={onClose} variant="outline" className="flex-1">
              Cancel
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
