import React from 'react';
import { Card, CardContent } from '../ui';
import { Button } from '../ui/Button';
import {
  Radio,
  MapPin,
  FileText,
  BarChart3,
  Camera,
  Mic,
  Terminal,
  Wifi,
} from 'lucide-react';

export interface QuickActionsProps {
  onBroadcastMessage?: () => void;
  onCaptureLocations?: () => void;
  onGenerateReport?: () => void;
  onViewAnalytics?: () => void;
  onBulkScreenshot?: () => void;
  onBulkAudio?: () => void;
  onExecuteCommand?: () => void;
  onNetworkScan?: () => void;
  disabled?: boolean;
}

export const QuickActions: React.FC<QuickActionsProps> = ({
  onBroadcastMessage,
  onCaptureLocations,
  onGenerateReport,
  onViewAnalytics,
  onBulkScreenshot,
  onBulkAudio,
  onExecuteCommand,
  onNetworkScan,
  disabled = false,
}) => {
  const actions = [
    {
      label: 'Broadcast Message',
      description: 'Send message to all devices',
      icon: <Radio size={20} />,
      onClick: onBroadcastMessage,
      variant: 'primary' as const,
    },
    {
      label: 'Capture Locations',
      description: 'Get location from all online devices',
      icon: <MapPin size={20} />,
      onClick: onCaptureLocations,
      variant: 'secondary' as const,
    },
    {
      label: 'Bulk Screenshot',
      description: 'Take screenshots from all devices',
      icon: <Camera size={20} />,
      onClick: onBulkScreenshot,
      variant: 'secondary' as const,
    },
    {
      label: 'Bulk Audio Record',
      description: 'Record audio from all devices',
      icon: <Mic size={20} />,
      onClick: onBulkAudio,
      variant: 'secondary' as const,
    },
    {
      label: 'Execute Command',
      description: 'Run shell command on all devices',
      icon: <Terminal size={20} />,
      onClick: onExecuteCommand,
      variant: 'secondary' as const,
    },
    {
      label: 'Network Scan',
      description: 'Scan network on all devices',
      icon: <Wifi size={20} />,
      onClick: onNetworkScan,
      variant: 'secondary' as const,
    },
    {
      label: 'Generate Report',
      description: 'Export activity and device data',
      icon: <FileText size={20} />,
      onClick: onGenerateReport,
      variant: 'secondary' as const,
    },
    {
      label: 'View Analytics',
      description: 'Open analytics dashboard',
      icon: <BarChart3 size={20} />,
      onClick: onViewAnalytics,
      variant: 'secondary' as const,
    },
  ];

  return (
    <Card variant="glass">
      <div className="p-6 border-b border-white/10">
        <h2 className="text-lg font-semibold text-white">Quick Actions</h2>
        <p className="text-sm text-white/50 mt-1">Common operations for connected devices</p>
      </div>
      <CardContent className="p-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {actions.map((action, index) => (
            <Button
              key={action.label}
              variant={action.variant}
              onClick={action.onClick}
              disabled={disabled || !action.onClick}
              className="h-auto flex-col items-start p-4 text-left animate-fade-in"
              style={{ animationDelay: `${index * 50}ms` }}
            >
              <div className="flex items-center gap-3 mb-2 w-full">
                <div className={`p-2 rounded-lg ${
                  action.variant === 'primary' 
                    ? 'bg-electric-500/20' 
                    : 'bg-white/10'
                }`}>
                  {action.icon}
                </div>
              </div>
              <div className="w-full">
                <div className="font-semibold text-sm mb-1">{action.label}</div>
                <div className="text-xs opacity-70">{action.description}</div>
              </div>
            </Button>
          ))}
        </div>
      </CardContent>
    </Card>
  );
};
