import React from 'react';
import { StatCard } from '../StatCard';
import {
  Activity,
  Smartphone,
  Terminal,
  Database,
  TrendingUp,
  AlertCircle,
} from 'lucide-react';

interface Metric {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  variant: 'electric' | 'cyber' | 'neon' | 'default';
  change?: {
    value: number;
    type: 'increase' | 'decrease';
  };
  subtitle?: string;
}

export interface MetricsGridProps {
  devicesOnline: number;
  totalDevices: number;
  commandsRun: number;
  activeSessions: number;
  dataCollected?: string;
  alerts?: number;
  loading?: boolean;
}

export const MetricsGrid: React.FC<MetricsGridProps> = ({
  devicesOnline,
  totalDevices,
  commandsRun,
  activeSessions,
  dataCollected = '0 MB',
  alerts = 0,
  loading = false,
}) => {
  const metrics: Metric[] = [
    {
      title: 'Devices Online',
      value: loading ? '...' : `${devicesOnline}/${totalDevices}`,
      icon: <Activity size={24} />,
      variant: 'electric',
      change: devicesOnline > 0 ? {
        value: Math.round((devicesOnline / Math.max(totalDevices, 1)) * 100),
        type: 'increase',
      } : undefined,
    },
    {
      title: 'Total Devices',
      value: loading ? '...' : totalDevices,
      icon: <Smartphone size={24} />,
      variant: 'cyber',
      change: totalDevices > 0 ? {
        value: totalDevices,
        type: 'increase',
      } : undefined,
    },
    {
      title: 'Commands Run',
      value: loading ? '...' : commandsRun,
      icon: <Terminal size={24} />,
      variant: 'neon',
      subtitle: 'Last 24 hours',
    },
    {
      title: 'Active Sessions',
      value: loading ? '...' : activeSessions,
      icon: <TrendingUp size={24} />,
      variant: 'default',
      subtitle: 'WebSocket connections',
    },
    {
      title: 'Data Collected',
      value: loading ? '...' : dataCollected,
      icon: <Database size={24} />,
      variant: 'cyber',
      subtitle: 'Total storage',
    },
    {
      title: 'Alerts',
      value: loading ? '...' : alerts,
      icon: <AlertCircle size={24} />,
      variant: 'electric',
      change: alerts > 0 ? {
        value: alerts,
        type: alerts > 5 ? 'increase' : 'decrease',
      } : undefined,
    },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {metrics.map((metric, index) => (
        <div
          key={metric.title}
          className="animate-fade-in"
          style={{ animationDelay: `${index * 100}ms` }}
        >
          <StatCard
            title={metric.title}
            value={metric.value}
            icon={metric.icon}
            variant={metric.variant}
            change={metric.change}
          />
          {metric.subtitle && (
            <p className="text-xs text-white/40 mt-2 ml-1">{metric.subtitle}</p>
          )}
        </div>
      ))}
    </div>
  );
};
