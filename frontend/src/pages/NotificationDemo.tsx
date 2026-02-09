import React, { useState } from 'react';
import { useNotification } from '@/hooks/useNotification';
import { useNotificationStore } from '@/stores/notificationStore';
import { NotificationSettings } from '@/components/settings/NotificationSettings';
import { Button } from '@/components/ui/Button';

export const NotificationDemo: React.FC = () => {
  const { notify } = useNotification();
  const [activeTab, setActiveTab] = useState<'demo' | 'settings'>('demo');
  const notifications = useNotificationStore((state) => state.notifications);
  const clearOlderThan = useNotificationStore((state) => state.clearOlderThan);

  const handleTestNotifications = () => {
    // Test all notification types
    setTimeout(() => notify.info('This is an info notification'), 0);
    setTimeout(() => notify.success('Operation completed successfully!'), 500);
    setTimeout(() => notify.warning('Warning: Low battery on device'), 1000);
    setTimeout(() => notify.error('Failed to execute command'), 1500);
    setTimeout(
      () =>
        notify.critical('Critical security breach detected!', {
          title: 'Security Alert',
          category: 'security',
        }),
      2000
    );
  };

  const handleTestWithAction = () => {
    notify.error('Failed to connect to device', {
      title: 'Connection Error',
      action: {
        label: 'Retry',
        onClick: () => {
          notify.info('Retrying connection...');
        },
      },
    });
  };

  const handleDeviceNotifications = () => {
    notify.success('Device "Samsung Galaxy S21" connected', {
      title: 'Device Connected',
      category: 'device',
      deviceId: 'device-123',
    });

    setTimeout(() => {
      notify.info('New data available from device', {
        title: 'New Data',
        category: 'device',
        deviceId: 'device-123',
      });
    }, 1500);
  };

  const handleCommandNotifications = () => {
    notify.info('Taking screenshot...', {
      title: 'Command Sent',
      category: 'command',
    });

    setTimeout(() => {
      notify.success('Screenshot captured successfully', {
        title: 'Command Completed',
        category: 'command',
      });
    }, 2000);
  };

  return (
    <div className="max-w-7xl mx-auto p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-white mb-2">Notification System Demo</h1>
        <p className="text-white/60">
          Test and configure the notification system with toasts, browser push, and notification center.
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        <button
          onClick={() => setActiveTab('demo')}
          className={`px-4 py-2 rounded-lg transition-all ${
            activeTab === 'demo'
              ? 'bg-electric-500 text-dark font-semibold'
              : 'bg-white/10 text-white/60 hover:bg-white/20'
          }`}
        >
          Demo
        </button>
        <button
          onClick={() => setActiveTab('settings')}
          className={`px-4 py-2 rounded-lg transition-all ${
            activeTab === 'settings'
              ? 'bg-electric-500 text-dark font-semibold'
              : 'bg-white/10 text-white/60 hover:bg-white/20'
          }`}
        >
          Settings
        </button>
      </div>

      {/* Content */}
      {activeTab === 'demo' ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Test Actions */}
          <div className="space-y-6">
            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">Test Notifications</h3>
              <div className="space-y-3">
                <Button onClick={handleTestNotifications} className="w-full">
                  🔔 Test All Notification Types
                </Button>
                <Button onClick={handleTestWithAction} variant="secondary" className="w-full">
                  ⚡ Test Notification with Action
                </Button>
                <Button onClick={handleDeviceNotifications} variant="secondary" className="w-full">
                  📱 Test Device Notifications
                </Button>
                <Button onClick={handleCommandNotifications} variant="secondary" className="w-full">
                  ⌨️ Test Command Notifications
                </Button>
              </div>
            </div>

            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">Individual Tests</h3>
              <div className="grid grid-cols-2 gap-2">
                <Button
                  onClick={() => notify.info('Info notification')}
                  variant="secondary"
                  size="sm"
                >
                  Info
                </Button>
                <Button
                  onClick={() => notify.success('Success notification')}
                  variant="secondary"
                  size="sm"
                >
                  Success
                </Button>
                <Button
                  onClick={() => notify.warning('Warning notification')}
                  variant="secondary"
                  size="sm"
                >
                  Warning
                </Button>
                <Button
                  onClick={() => notify.error('Error notification')}
                  variant="secondary"
                  size="sm"
                >
                  Error
                </Button>
                <Button
                  onClick={() => notify.critical('Critical notification')}
                  variant="danger"
                  size="sm"
                  className="col-span-2"
                >
                  Critical
                </Button>
              </div>
            </div>

            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">Notification History</h3>
              <div className="space-y-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-white/60">Total Notifications:</span>
                  <span className="text-white font-semibold">{notifications.length}</span>
                </div>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-white/60">Unread:</span>
                  <span className="text-white font-semibold">
                    {notifications.filter((n) => !n.read).length}
                  </span>
                </div>
                <Button
                  onClick={() => clearOlderThan(7)}
                  variant="danger"
                  size="sm"
                  className="w-full mt-3"
                >
                  Clear Old Notifications (7+ days)
                </Button>
              </div>
            </div>
          </div>

          {/* Documentation */}
          <div className="space-y-6">
            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">📖 Usage</h3>
              <div className="space-y-4 text-sm text-white/80">
                <div>
                  <h4 className="font-semibold text-white mb-2">Basic Usage:</h4>
                  <pre className="bg-dark/50 p-3 rounded overflow-x-auto">
                    <code>{`const { notify } = useNotification();

notify.success('Device connected');
notify.error('Command failed');
notify.warning('Low battery');
notify.info('New data available');
notify.critical('Security breach');`}</code>
                  </pre>
                </div>

                <div>
                  <h4 className="font-semibold text-white mb-2">With Options:</h4>
                  <pre className="bg-dark/50 p-3 rounded overflow-x-auto">
                    <code>{`notify.error('Connection failed', {
  title: 'Connection Error',
  action: {
    label: 'Retry',
    onClick: () => retryConnection()
  },
  category: 'device',
  deviceId: 'device-123'
});`}</code>
                  </pre>
                </div>

                <div>
                  <h4 className="font-semibold text-white mb-2">Features:</h4>
                  <ul className="list-disc list-inside space-y-1 text-white/60">
                    <li>Toast notifications with auto-dismiss</li>
                    <li>Notification center with history</li>
                    <li>Browser push notifications</li>
                    <li>Sound effects (optional)</li>
                    <li>Do Not Disturb mode</li>
                    <li>Priority levels</li>
                    <li>Action buttons</li>
                    <li>Categorization & filtering</li>
                  </ul>
                </div>
              </div>
            </div>

            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">🔔 Notification Bell</h3>
              <p className="text-white/60 text-sm mb-3">
                Click the bell icon in the top-right corner to:
              </p>
              <ul className="list-disc list-inside space-y-1 text-sm text-white/60">
                <li>View all notifications</li>
                <li>Filter by type (info, success, warning, error)</li>
                <li>Mark as read/unread</li>
                <li>Clear notifications</li>
                <li>View grouped by date (Today, Yesterday, Older)</li>
              </ul>
            </div>

            <div className="glass-dark p-6 rounded-lg border border-white/20">
              <h3 className="text-xl font-semibold text-white mb-4">🔊 Browser Permissions</h3>
              <p className="text-white/60 text-sm mb-3">
                To enable browser push notifications and sound effects:
              </p>
              <ol className="list-decimal list-inside space-y-1 text-sm text-white/60">
                <li>Go to the Settings tab</li>
                <li>Click "Request Permission" for push notifications</li>
                <li>Allow browser notifications when prompted</li>
                <li>Toggle sound effects and adjust volume</li>
              </ol>
            </div>
          </div>
        </div>
      ) : (
        <div className="max-w-3xl">
          <NotificationSettings />
        </div>
      )}
    </div>
  );
};
