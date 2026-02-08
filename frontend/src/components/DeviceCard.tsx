import React from 'react';
import { Card, CardHeader, CardTitle, CardContent, Badge, Avatar } from './ui';

export interface DeviceInfo {
  id: string;
  name: string;
  model: string;
  os: string;
  status: 'online' | 'offline' | 'idle';
  lastSeen: string;
  batteryLevel?: number;
  location?: string;
}

export interface DeviceCardProps {
  device: DeviceInfo;
  onClick?: (device: DeviceInfo) => void;
  onAction?: (action: string, device: DeviceInfo) => void;
}

const statusConfig = {
  online: { variant: 'success' as const, label: 'Online', dot: true },
  offline: { variant: 'danger' as const, label: 'Offline', dot: false },
  idle: { variant: 'warning' as const, label: 'Idle', dot: true },
};

export const DeviceCard: React.FC<DeviceCardProps> = ({ device, onClick, onAction }) => {
  const status = statusConfig[device.status];

  return (
    <Card variant="glass" hover className="group" onClick={() => onClick?.(device)}>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <Avatar
              fallback={device.name[0]}
              size="lg"
              status={device.status}
            />
            <div>
              <CardTitle className="group-hover:text-electric-400 transition-colors">
                {device.name}
              </CardTitle>
              <p className="text-sm text-white/60">{device.model}</p>
            </div>
          </div>
          <Badge variant={status.variant} dot={status.dot}>
            {status.label}
          </Badge>
        </div>
      </CardHeader>

      <CardContent>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <div>
            <span className="text-white/60">OS:</span>
            <span className="ml-2 text-white">{device.os}</span>
          </div>
          {device.batteryLevel !== undefined && (
            <div>
              <span className="text-white/60">Battery:</span>
              <span className="ml-2 text-white">{device.batteryLevel}%</span>
            </div>
          )}
          <div>
            <span className="text-white/60">Last Seen:</span>
            <span className="ml-2 text-white">{device.lastSeen}</span>
          </div>
          {device.location && (
            <div>
              <span className="text-white/60">Location:</span>
              <span className="ml-2 text-white">{device.location}</span>
            </div>
          )}
        </div>
      </CardContent>

      <div className="mt-4 flex gap-2">
        <button
          onClick={(e) => {
            e.stopPropagation();
            onAction?.('view', device);
          }}
          className="flex-1 px-3 py-2 text-sm rounded-lg bg-electric-500/20 hover:bg-electric-500/30 text-electric-400 transition-colors"
        >
          View Details
        </button>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onAction?.('command', device);
          }}
          className="flex-1 px-3 py-2 text-sm rounded-lg bg-cyber-500/20 hover:bg-cyber-500/30 text-cyber-400 transition-colors"
        >
          Commands
        </button>
      </div>
    </Card>
  );
};
