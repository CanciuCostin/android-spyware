import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useLayoutStore } from '../stores/layoutStore';
import { useDevices } from '../hooks/useDevices';
import { Breadcrumbs } from '../components/layout';
import { DeviceCard } from '../components/DeviceCard';
import { Smartphone, Plus } from 'lucide-react';

export function DevicesPage() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);
  const { devices, loading } = useDevices();
  const navigate = useNavigate();

  useEffect(() => {
    setBreadcrumbs([{ label: 'Devices' }]);
  }, [setBreadcrumbs]);

  const handleDeviceClick = (deviceId: string) => {
    navigate(`/devices/${deviceId}`);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <Breadcrumbs items={[{ label: 'Devices' }]} />
          <h1 className="text-3xl font-bold text-gray-900 mt-2">Devices</h1>
          <p className="text-gray-600 mt-1">Manage all connected devices</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2 bg-cyan-600 text-white rounded-lg
          hover:bg-cyan-700 transition-colors">
          <Plus size={20} />
          Add Device
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-12 h-12 border-4 border-cyan-600 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : devices.length === 0 ? (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-6">
            <div className="text-center py-12">
              <Smartphone size={48} className="mx-auto text-gray-400 mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No devices found</h3>
              <p className="text-gray-600 mb-6">Get started by adding your first device</p>
              <button className="px-6 py-2 bg-cyan-600 text-white rounded-lg
                hover:bg-cyan-700 transition-colors">
                Add Device
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {devices.map((device) => (
            <DeviceCard
              key={device.id}
              device={{
                id: device.id,
                name: device.name,
                model: device.model || 'Unknown',
                os: `Android ${device.androidVersion || 'Unknown'}`,
                status: device.status === 'online' ? 'online' : device.status === 'offline' ? 'offline' : 'idle',
                lastSeen: device.lastSeen,
                batteryLevel: device.batteryLevel,
                location: device.location ? `${device.location.latitude.toFixed(2)}, ${device.location.longitude.toFixed(2)}` : undefined,
              }}
              onClick={() => handleDeviceClick(device.id)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
