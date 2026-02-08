import React, { useState, useMemo } from 'react';
import { Card, CardContent } from '../ui';
import { Badge } from '../ui/Badge';
import { Input } from '../ui/Input';
import { Button } from '../ui/Button';
import {
  Smartphone,
  Battery,
  BatteryCharging,
  MapPin,
  Camera,
  Mic,
  ChevronDown,
  Search,
  Filter,
} from 'lucide-react';
import type { Device } from '../../types/api';
import { DeviceStatus } from '../../types/api';
import { formatDistanceToNow } from '../../utils/dateUtils';

export interface DeviceGridProps {
  devices: Device[];
  onDeviceClick?: (device: Device) => void;
  onQuickAction?: (device: Device, action: 'location' | 'camera' | 'mic') => void;
  loading?: boolean;
}

type SortField = 'name' | 'status' | 'lastSeen' | 'battery';
type SortOrder = 'asc' | 'desc';

export const DeviceGrid: React.FC<DeviceGridProps> = ({
  devices,
  onDeviceClick,
  onQuickAction,
  loading = false,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState<SortField>('lastSeen');
  const [, setSortOrder] = useState<SortOrder>('desc');
  const [showSortMenu, setShowSortMenu] = useState(false);

  const filteredAndSortedDevices = useMemo(() => {
    let filtered = devices;

    // Apply search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = devices.filter(
        (device) =>
          device.name.toLowerCase().includes(query) ||
          device.model.toLowerCase().includes(query) ||
          device.manufacturer.toLowerCase().includes(query)
      );
    }

    // Apply sorting
    const sorted = [...filtered].sort((a, b) => {
      let comparison = 0;

      switch (sortField) {
        case 'name':
          comparison = a.name.localeCompare(b.name);
          break;
        case 'status':
          comparison = a.status.localeCompare(b.status);
          break;
        case 'lastSeen':
          comparison = new Date(a.lastSeen).getTime() - new Date(b.lastSeen).getTime();
          break;
        case 'battery':
          comparison = (a.batteryLevel || 0) - (b.batteryLevel || 0);
          break;
      }

      return sortOrder === 'asc' ? comparison : -comparison;
    });

    return sorted;
  }, [devices, searchQuery, sortField, sortOrder]);

  const getStatusColor = (status: string) => {
    switch (status) {
      case DeviceStatus.ONLINE:
        return 'success';
      case DeviceStatus.OFFLINE:
        return 'danger';
      case DeviceStatus.IDLE:
        return 'warning';
      case DeviceStatus.BUSY:
        return 'info';
      default:
        return 'default';
    }
  };

  const getStatusText = (status: string) => {
    return status.charAt(0).toUpperCase() + status.slice(1);
  };

  const formatLastSeen = (lastSeen: string) => {
    try {
      return formatDistanceToNow(new Date(lastSeen), { addSuffix: true });
    } catch {
      return 'Unknown';
    }
  };

  if (loading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {[...Array(6)].map((_, i) => (
          <Card key={i} variant="glass">
            <CardContent className="p-6">
              <div className="animate-pulse">
                <div className="h-4 bg-white/10 rounded w-3/4 mb-4"></div>
                <div className="h-3 bg-white/10 rounded w-1/2 mb-2"></div>
                <div className="h-3 bg-white/10 rounded w-2/3"></div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Search and Filter Bar */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="flex-1">
          <Input
            placeholder="Search devices..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            icon={<Search size={18} />}
          />
        </div>
        <div className="relative">
          <Button
            variant="secondary"
            onClick={() => setShowSortMenu(!showSortMenu)}
            className="w-full sm:w-auto"
          >
            <Filter size={18} className="mr-2" />
            Sort: {sortField}
            <ChevronDown size={18} className="ml-2" />
          </Button>
          {showSortMenu && (
            <div className="absolute right-0 mt-2 w-48 bg-dark-800 border border-white/10 rounded-lg shadow-lg z-10">
              <div className="py-2">
                {(['name', 'status', 'lastSeen', 'battery'] as SortField[]).map((field) => (
                  <button
                    key={field}
                    onClick={() => {
                      setSortField(field);
                      setShowSortMenu(false);
                    }}
                    className="w-full text-left px-4 py-2 hover:bg-white/5 text-white text-sm"
                  >
                    {field.charAt(0).toUpperCase() + field.slice(1)}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Device Grid */}
      {filteredAndSortedDevices.length === 0 ? (
        <Card variant="glass">
          <CardContent className="p-12 text-center">
            <Smartphone size={48} className="mx-auto mb-4 text-white/30" />
            <p className="text-white/60">
              {searchQuery ? 'No devices found matching your search' : 'No devices connected'}
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredAndSortedDevices.map((device, index) => (
            <Card
              key={device.id}
              variant="glass"
              hover
              className="cursor-pointer animate-fade-in"
              style={{ animationDelay: `${index * 50}ms` }}
              onClick={() => onDeviceClick?.(device)}
            >
              <CardContent className="p-6">
                {/* Header */}
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-cyber-500/10 rounded-lg">
                      <Smartphone size={20} className="text-cyber-400" />
                    </div>
                    <div>
                      <h3 className="font-semibold text-white">{device.name}</h3>
                      <p className="text-xs text-white/50">{device.model}</p>
                    </div>
                  </div>
                  <Badge variant={getStatusColor(device.status)}>
                    {getStatusText(device.status)}
                  </Badge>
                </div>

                {/* Info */}
                <div className="space-y-2 mb-4">
                  <div className="flex items-center gap-2 text-sm text-white/60">
                    {device.isCharging ? (
                      <BatteryCharging size={16} className="text-neon-400" />
                    ) : (
                      <Battery size={16} />
                    )}
                    <span>{device.batteryLevel || 0}%</span>
                  </div>
                  <div className="text-xs text-white/40">
                    Last seen: {formatLastSeen(device.lastSeen)}
                  </div>
                </div>

                {/* Quick Actions */}
                <div className="flex gap-2 pt-4 border-t border-white/10">
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      onQuickAction?.(device, 'location');
                    }}
                    disabled={device.status !== DeviceStatus.ONLINE}
                    className="flex-1"
                  >
                    <MapPin size={16} />
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      onQuickAction?.(device, 'camera');
                    }}
                    disabled={device.status !== DeviceStatus.ONLINE}
                    className="flex-1"
                  >
                    <Camera size={16} />
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      onQuickAction?.(device, 'mic');
                    }}
                    disabled={device.status !== DeviceStatus.ONLINE}
                    className="flex-1"
                  >
                    <Mic size={16} />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
};
