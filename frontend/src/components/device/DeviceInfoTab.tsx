import React from 'react';
import type { Device } from '../../types/api';
import { Card, CardHeader, CardTitle, CardContent, Badge } from '../ui';

interface DeviceInfoTabProps {
  device: Device;
}

export const DeviceInfoTab: React.FC<DeviceInfoTabProps> = ({ device }) => {
  const formatBytes = (bytes?: number) => {
    if (!bytes) return 'N/A';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  };

  const metadata = device.metadata as Record<string, any> || {};
  const storageTotal = metadata.storageTotal;
  const storageUsed = metadata.storageUsed;
  const storagePercent = storageTotal && storageUsed ? ((storageUsed / storageTotal) * 100).toFixed(1) : null;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Device Information */}
      <Card variant="glass">
        <CardHeader>
          <CardTitle>Device Information</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <InfoRow label="Device Name" value={device.name} />
          <InfoRow label="Manufacturer" value={device.manufacturer} />
          <InfoRow label="Model" value={device.model} />
          <InfoRow label="Android Version" value={device.androidVersion} />
          <InfoRow label="Device ID" value={device.id} mono />
          <InfoRow label="IP Address" value={device.ipAddress || 'Unknown'} />
          <InfoRow label="Status" value={<Badge variant={device.status === 'online' ? 'success' : 'danger'}>{device.status}</Badge>} />
        </CardContent>
      </Card>

      {/* System Status */}
      <Card variant="glass">
        <CardHeader>
          <CardTitle>System Status</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Battery */}
          <div>
            <div className="flex justify-between text-sm mb-2">
              <span className="text-white/60">Battery Level</span>
              <span className="text-white">{device.batteryLevel || 'N/A'}%</span>
            </div>
            {device.batteryLevel && (
              <div className="h-2 bg-white/10 rounded-full overflow-hidden">
                <div
                  className={`h-full transition-all ${
                    device.batteryLevel > 50 ? 'bg-green-500' :
                    device.batteryLevel > 20 ? 'bg-yellow-500' : 'bg-red-500'
                  }`}
                  style={{ width: `${device.batteryLevel}%` }}
                />
              </div>
            )}
            {device.isCharging && (
              <div className="text-xs text-green-400 mt-1">⚡ Charging</div>
            )}
          </div>

          {/* Storage */}
          {storageTotal && (
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-white/60">Storage</span>
                <span className="text-white">{formatBytes(storageUsed)} / {formatBytes(storageTotal)}</span>
              </div>
              <div className="h-2 bg-white/10 rounded-full overflow-hidden">
                <div
                  className="h-full bg-electric-500 transition-all"
                  style={{ width: `${storagePercent}%` }}
                />
              </div>
              <div className="text-xs text-white/60 mt-1">{storagePercent}% used</div>
            </div>
          )}

          {/* Network */}
          <InfoRow label="Carrier" value={metadata.carrier || 'Unknown'} />
          <InfoRow label="WiFi SSID" value={metadata.wifiSsid || 'Not connected'} />
          <InfoRow label="Network Type" value={metadata.networkType || 'Unknown'} />
        </CardContent>
      </Card>

      {/* Location & Time */}
      <Card variant="glass">
        <CardHeader>
          <CardTitle>Location & Time</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {device.location ? (
            <>
              <InfoRow label="Latitude" value={device.location.latitude.toFixed(6)} />
              <InfoRow label="Longitude" value={device.location.longitude.toFixed(6)} />
              <InfoRow label="Accuracy" value={device.location.accuracy ? `${device.location.accuracy}m` : 'N/A'} />
              {device.location.timestamp && (
                <InfoRow label="Location Time" value={new Date(device.location.timestamp).toLocaleString()} />
              )}
            </>
          ) : (
            <div className="text-white/40 text-center py-8">
              No location data available
            </div>
          )}
          <InfoRow label="Last Seen" value={new Date(device.lastSeen).toLocaleString()} />
          <InfoRow label="First Seen" value={new Date(device.createdAt).toLocaleString()} />
        </CardContent>
      </Card>

      {/* Quick Stats */}
      <Card variant="glass">
        <CardHeader>
          <CardTitle>Activity Stats</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <StatItem icon="📸" label="Photos Captured" value={metadata.photoCount || 0} />
          <StatItem icon="📹" label="Videos Recorded" value={metadata.videoCount || 0} />
          <StatItem icon="⌨️" label="Keylog Entries" value={metadata.keylogCount || 0} />
          <StatItem icon="📞" label="Call Logs" value={metadata.callLogCount || 0} />
          <StatItem icon="💬" label="SMS Messages" value={metadata.smsCount || 0} />
          <StatItem icon="⚡" label="Commands Executed" value={metadata.commandCount || 0} />
        </CardContent>
      </Card>
    </div>
  );
};

const InfoRow: React.FC<{ label: string; value: React.ReactNode; mono?: boolean }> = ({ label, value, mono }) => (
  <div className="flex justify-between items-center">
    <span className="text-white/60 text-sm">{label}</span>
    <span className={`text-white text-sm ${mono ? 'font-mono' : ''}`}>{value}</span>
  </div>
);

const StatItem: React.FC<{ icon: string; label: string; value: number }> = ({ icon, label, value }) => (
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-2">
      <span className="text-2xl">{icon}</span>
      <span className="text-white/60 text-sm">{label}</span>
    </div>
    <span className="text-white font-bold text-lg">{value.toLocaleString()}</span>
  </div>
);
