import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { BulkOperationsPanel } from '../../components/fleet/BulkOperationsPanel';
import { Button } from '../../components/ui/button';
import { ArrowLeft, Users, Activity, Battery } from 'lucide-react';

interface Device {
  id: number;
  target_ip: string;
  device_name: string;
  status: string;
  battery_level?: number;
  last_seen_at?: string;
  device_tags?: Array<{ key: string; value: string }>;
}

interface DeviceGroup {
  id: number;
  name: string;
  description: string;
  color: string;
  online_count: number;
  total_count: number;
  battery_average: number;
  devices: Device[];
}

export const FleetDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [group, setGroup] = useState<DeviceGroup | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedDevices, setSelectedDevices] = useState<number[]>([]);

  useEffect(() => {
    fetchGroupDetails();
  }, [id]);

  const fetchGroupDetails = async () => {
    try {
      const response = await fetch(`/device_groups/${id}`);
      const data = await response.json();
      setGroup(data);
    } catch (error) {
      console.error('Failed to fetch group details:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleBulkCommand = async (commandType: string, params: any) => {
    try {
      const response = await fetch(`/device_groups/${id}/bulk_command`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          command_type: commandType,
          command_params: params,
        }),
      });

      if (response.ok) {
        const result = await response.json();
        alert(`Command sent to ${result.sent} devices`);
      }
    } catch (error) {
      console.error('Failed to send bulk command:', error);
    }
  };

  const handleRemoveDevices = async () => {
    if (selectedDevices.length === 0) return;

    try {
      const response = await fetch(`/device_groups/${id}/remove_devices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_ids: selectedDevices }),
      });

      if (response.ok) {
        setSelectedDevices([]);
        fetchGroupDetails();
      }
    } catch (error) {
      console.error('Failed to remove devices:', error);
    }
  };

  const toggleDeviceSelection = (deviceId: number) => {
    setSelectedDevices((prev) =>
      prev.includes(deviceId)
        ? prev.filter((id) => id !== deviceId)
        : [...prev, deviceId]
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500" />
      </div>
    );
  }

  if (!group) {
    return (
      <div className="container mx-auto p-6">
        <p className="text-red-500">Group not found</p>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6">
      <div className="mb-8">
        <Button
          onClick={() => navigate('/fleet')}
          variant="ghost"
          className="mb-4 flex items-center gap-2"
        >
          <ArrowLeft size={20} />
          Back to Fleet
        </Button>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div
              className="w-12 h-12 rounded-lg"
              style={{ backgroundColor: group.color }}
            />
            <div>
              <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
                {group.name}
              </h1>
              <p className="text-gray-600 dark:text-gray-400">{group.description}</p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <Users className="text-blue-600 dark:text-blue-400" size={24} />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Devices</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {group.total_count}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <Activity className="text-green-600 dark:text-green-400" size={24} />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Online</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {group.online_count}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <Battery className="text-yellow-600 dark:text-yellow-400" size={24} />
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Avg Battery</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {group.battery_average}%
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="mb-8">
        <BulkOperationsPanel onExecute={handleBulkCommand} />
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-lg shadow">
        <div className="p-6 border-b dark:border-gray-700 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">
            Devices ({group.devices.length})
          </h2>
          {selectedDevices.length > 0 && (
            <Button onClick={handleRemoveDevices} variant="destructive">
              Remove Selected ({selectedDevices.length})
            </Button>
          )}
        </div>

        <div className="divide-y dark:divide-gray-700">
          {group.devices.map((device) => (
            <div
              key={device.id}
              className="p-4 hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-4"
            >
              <input
                type="checkbox"
                checked={selectedDevices.includes(device.id)}
                onChange={() => toggleDeviceSelection(device.id)}
                className="w-5 h-5"
              />
              <div className="flex-1">
                <p className="font-semibold text-gray-900 dark:text-white">
                  {device.device_name || device.target_ip}
                </p>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  {device.target_ip}
                </p>
              </div>
              <div className="flex items-center gap-4">
                <span
                  className={`px-3 py-1 rounded-full text-sm ${
                    device.status === 'online'
                      ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                      : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
                  }`}
                >
                  {device.status}
                </span>
                {device.battery_level && (
                  <span className="text-sm text-gray-600 dark:text-gray-400">
                    🔋 {device.battery_level}%
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
