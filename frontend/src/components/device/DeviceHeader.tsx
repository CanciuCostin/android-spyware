import React, { useState } from 'react';
import type { Device } from '../../types/api';
import { DeviceStatus } from '../../types/api';
import { Card, Badge, Avatar } from '../ui';
import { getApiService } from '../../services/api';

const api = getApiService();

interface DeviceHeaderProps {
  device: Device;
  onRefresh?: () => void;
}

const statusConfig: Record<DeviceStatus, { variant: 'success' | 'warning' | 'danger' | 'default'; label: string; dot: boolean }> = {
  [DeviceStatus.ONLINE]: { variant: 'success', label: 'Online', dot: true },
  [DeviceStatus.OFFLINE]: { variant: 'danger', label: 'Offline', dot: false },
  [DeviceStatus.IDLE]: { variant: 'warning', label: 'Idle', dot: true },
  [DeviceStatus.BUSY]: { variant: 'warning', label: 'Busy', dot: true },
  [DeviceStatus.ERROR]: { variant: 'danger', label: 'Error', dot: true },
};

export const DeviceHeader: React.FC<DeviceHeaderProps> = ({ device, onRefresh }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editedName, setEditedName] = useState(device.name);
  const [isSaving, setIsSaving] = useState(false);

  const status = statusConfig[device.status] || statusConfig[DeviceStatus.OFFLINE];

  const handleSaveName = async () => {
    if (editedName.trim() === device.name) {
      setIsEditing(false);
      return;
    }

    setIsSaving(true);
    try {
      await api.updateDevice(device.id, { name: editedName.trim() });
      setIsEditing(false);
      onRefresh?.();
    } catch (error) {
      console.error('Failed to update device name:', error);
      setEditedName(device.name);
    } finally {
      setIsSaving(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSaveName();
    } else if (e.key === 'Escape') {
      setEditedName(device.name);
      setIsEditing(false);
    }
  };

  const getBatteryIcon = (level?: number, isCharging?: boolean) => {
    if (level === undefined) return '🔋';
    if (isCharging) return '⚡';
    if (level > 80) return '🔋';
    if (level > 50) return '🔋';
    if (level > 20) return '🪫';
    return '🪫';
  };

  const getBatteryColor = (level?: number) => {
    if (level === undefined) return 'text-white/40';
    if (level > 50) return 'text-green-400';
    if (level > 20) return 'text-yellow-400';
    return 'text-red-400';
  };

  const getTimeSince = (dateString: string) => {
    const now = new Date();
    const date = new Date(dateString);
    const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (seconds < 60) return 'just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  };

  return (
    <Card variant="glass" className="p-6">
      <div className="flex items-start justify-between">
        {/* Left Side - Device Info */}
        <div className="flex items-start gap-4">
          <Avatar
            fallback={device.name[0]}
            size="xl"
            status={device.status as 'online' | 'offline' | 'idle' | 'busy' | 'away'}
            className="mt-1"
          />
          <div>
            {/* Device Name */}
            <div className="flex items-center gap-2 mb-2">
              {isEditing ? (
                <input
                  type="text"
                  value={editedName}
                  onChange={(e) => setEditedName(e.target.value)}
                  onBlur={handleSaveName}
                  onKeyDown={handleKeyPress}
                  disabled={isSaving}
                  className="text-2xl font-bold bg-white/5 border border-white/20 rounded px-2 py-1 focus:outline-none focus:border-electric-500"
                  autoFocus
                />
              ) : (
                <>
                  <h1 className="text-2xl font-bold text-white">{device.name}</h1>
                  <button
                    onClick={() => setIsEditing(true)}
                    className="p-1 hover:bg-white/10 rounded transition-colors"
                    title="Edit name"
                  >
                    ✏️
                  </button>
                </>
              )}
            </div>

            {/* Device Details */}
            <div className="flex items-center gap-4 text-sm text-white/60">
              <span>{device.manufacturer} {device.model}</span>
              <span>•</span>
              <span>Android {device.androidVersion}</span>
              {device.ipAddress && (
                <>
                  <span>•</span>
                  <span>IP: {device.ipAddress}</span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Right Side - Status & Actions */}
        <div className="flex items-start gap-4">
          {/* Status Info */}
          <div className="text-right space-y-2">
            <div className="flex items-center justify-end gap-2">
              <Badge variant={status.variant} dot={status.dot}>
                {status.label}
              </Badge>
            </div>
            <div className="text-sm text-white/60">
              Last seen: {getTimeSince(device.lastSeen)}
            </div>
            {device.batteryLevel !== undefined && (
              <div className={`flex items-center justify-end gap-1 text-sm ${getBatteryColor(device.batteryLevel)}`}>
                <span>{getBatteryIcon(device.batteryLevel, device.isCharging)}</span>
                <span>{device.batteryLevel}%</span>
              </div>
            )}
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-2">
            <button
              onClick={onRefresh}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
              title="Refresh"
            >
              🔄
            </button>
            <button
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
              title="Settings"
            >
              ⚙️
            </button>
            <button
              className="p-2 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors"
              title="Delete device"
              onClick={() => {
                if (confirm(`Are you sure you want to delete ${device.name}?`)) {
                  api.deleteDevice(device.id);
                }
              }}
            >
              🗑️
            </button>
          </div>
        </div>
      </div>
    </Card>
  );
};
