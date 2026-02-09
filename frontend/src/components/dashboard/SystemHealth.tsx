import React, { useEffect, useState } from 'react';
import { Card, CardContent } from '../ui';
import { Badge } from '../ui/Badge';
import {
  Server,
  Database,
  Radio,
  Zap,
  CheckCircle,
  AlertTriangle,
  XCircle,
} from 'lucide-react';
import { useWebSocket } from '../../hooks/useWebSocket';
import { ConnectionStatus } from '../../types/api';

interface HealthIndicator {
  name: string;
  status: 'healthy' | 'warning' | 'error' | 'unknown';
  message?: string;
  icon: React.ReactNode;
}

export interface SystemHealthProps {
  serverStatus?: 'healthy' | 'warning' | 'error';
  databaseStatus?: 'healthy' | 'warning' | 'error';
  redisStatus?: 'healthy' | 'warning' | 'error';
  loading?: boolean;
}

export const SystemHealth: React.FC<SystemHealthProps> = ({
  serverStatus = 'healthy',
  databaseStatus = 'healthy',
  redisStatus = 'healthy',
  loading = false,
}) => {
  const { status: wsStatus, isConnected } = useWebSocket();
  const [lastUpdate, setLastUpdate] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => {
      setLastUpdate(new Date());
    }, 30000); // Update every 30 seconds

    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status: string): 'success' | 'warning' | 'danger' | 'default' => {
    switch (status) {
      case 'healthy':
        return 'success';
      case 'warning':
        return 'warning';
      case 'error':
        return 'danger';
      default:
        return 'default';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'healthy':
        return <CheckCircle size={16} className="text-neon-400" />;
      case 'warning':
        return <AlertTriangle size={16} className="text-yellow-400" />;
      case 'error':
        return <XCircle size={16} className="text-red-400" />;
      default:
        return <AlertTriangle size={16} className="text-white/40" />;
    }
  };

  const getWebSocketStatus = (): 'healthy' | 'warning' | 'error' => {
    switch (wsStatus) {
      case ConnectionStatus.CONNECTED:
        return 'healthy';
      case ConnectionStatus.CONNECTING:
      case ConnectionStatus.RECONNECTING:
        return 'warning';
      case ConnectionStatus.DISCONNECTED:
      case ConnectionStatus.ERROR:
        return 'error';
      default:
        return 'warning';
    }
  };

  const indicators: HealthIndicator[] = [
    {
      name: 'Server',
      status: serverStatus,
      message: serverStatus === 'healthy' ? 'Running' : 'Issues detected',
      icon: <Server size={20} />,
    },
    {
      name: 'Database',
      status: databaseStatus,
      message: databaseStatus === 'healthy' ? 'Connected' : 'Connection issues',
      icon: <Database size={20} />,
    },
    {
      name: 'WebSocket',
      status: getWebSocketStatus(),
      message: isConnected ? 'Connected' : wsStatus,
      icon: <Radio size={20} />,
    },
    {
      name: 'Redis',
      status: redisStatus,
      message: redisStatus === 'healthy' ? 'Online' : 'Unavailable',
      icon: <Zap size={20} />,
    },
  ];

  const overallHealth = indicators.every((i) => i.status === 'healthy')
    ? 'healthy'
    : indicators.some((i) => i.status === 'error')
    ? 'error'
    : 'warning';

  if (loading) {
    return (
      <Card variant="glass">
        <CardContent className="p-6">
          <div className="animate-pulse">
            <div className="h-4 bg-white/10 rounded w-1/2 mb-4"></div>
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="h-12 bg-white/10 rounded"></div>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card variant="glass">
      <div className="p-6 border-b border-white/10">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <Activity size={20} />
            System Health
          </h2>
          <Badge variant={getStatusColor(overallHealth)}>
            {overallHealth === 'healthy' ? 'All Systems Operational' : 'Issues Detected'}
          </Badge>
        </div>
      </div>
      <CardContent className="p-6">
        <div className="space-y-4">
          {indicators.map((indicator, index) => (
            <div
              key={indicator.name}
              className="flex items-center justify-between p-4 bg-white/5 rounded-lg hover:bg-white/10 transition-colors animate-fade-in"
              style={{ animationDelay: `${index * 100}ms` }}
            >
              <div className="flex items-center gap-3">
                <div className={`p-2 rounded-lg ${
                  indicator.status === 'healthy' ? 'bg-neon-500/10' :
                  indicator.status === 'warning' ? 'bg-yellow-500/10' :
                  'bg-red-500/10'
                }`}>
                  {indicator.icon}
                </div>
                <div>
                  <h4 className="text-sm font-medium text-white">{indicator.name}</h4>
                  <p className="text-xs text-white/50">{indicator.message}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {getStatusIcon(indicator.status)}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-6 pt-4 border-t border-white/10">
          <div className="flex items-center justify-between text-xs text-white/40">
            <span>Last updated</span>
            <span>{lastUpdate.toLocaleTimeString()}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

// Activity import fix
function Activity({ size }: { size: number }) {
  return <Server size={size} />;
}
