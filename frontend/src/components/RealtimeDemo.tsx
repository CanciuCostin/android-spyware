import { useEffect, useState } from 'react';
import { useDevices } from '../hooks/useDevices';
import { useCommand } from '../hooks/useCommand';
import { useRealtime } from '../hooks/useRealtime';
import { useUIStore } from '../stores/uiStore';
import { CommandType, DeviceStatus } from '../types/api';

export function RealtimeDemo() {
  const { isConnected, status } = useRealtime();
  const { devices, loading: devicesLoading, error: devicesError } = useDevices();
  const { execute, loading: commandLoading, error: commandError } = useCommand();
  const notifications = useUIStore((state) => state.notifications);
  const removeNotification = useUIStore((state) => state.removeNotification);

  const [selectedDeviceId, setSelectedDeviceId] = useState<string | null>(null);
  const [commandResult, setCommandResult] = useState<string | null>(null);

  useEffect(() => {
    console.log('Realtime Demo mounted');
    console.log('Connection Status:', status);
    console.log('Is Connected:', isConnected);
  }, [status, isConnected]);

  const handleSendTestCommand = async () => {
    if (!selectedDeviceId) {
      alert('Please select a device first');
      return;
    }

    setCommandResult('Sending command...');

    const command = await execute(selectedDeviceId, CommandType.SHELL, {
      command: 'echo "Hello from React!"',
    });

    if (command) {
      setCommandResult(`Command sent! ID: ${command.id}, Status: ${command.status}`);
    } else {
      setCommandResult('Failed to send command');
    }
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'monospace' }}>
      <h1>🚀 Real-time Data Layer Demo</h1>

      {/* Connection Status */}
      <div style={{ marginBottom: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h2>Connection Status</h2>
        <p>
          <strong>Status:</strong>{' '}
          <span style={{ color: isConnected ? 'green' : 'red' }}>{status}</span>
        </p>
        <p>
          <strong>Connected:</strong> {isConnected ? '✅' : '❌'}
        </p>
      </div>

      {/* Devices */}
      <div style={{ marginBottom: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h2>Devices ({devices.length})</h2>
        {devicesLoading && <p>Loading devices...</p>}
        {devicesError && <p style={{ color: 'red' }}>Error: {devicesError}</p>}

        {!devicesLoading && devices.length === 0 && <p>No devices connected</p>}

        {devices.length > 0 && (
          <div>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>Select</th>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>ID</th>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>Name</th>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>Model</th>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>Status</th>
                  <th style={{ border: '1px solid #ccc', padding: '8px' }}>Last Seen</th>
                </tr>
              </thead>
              <tbody>
                {devices.map((device) => (
                  <tr key={device.id}>
                    <td style={{ border: '1px solid #ccc', padding: '8px', textAlign: 'center' }}>
                      <input
                        type="radio"
                        name="device"
                        checked={selectedDeviceId === device.id}
                        onChange={() => setSelectedDeviceId(device.id)}
                      />
                    </td>
                    <td style={{ border: '1px solid #ccc', padding: '8px' }}>{device.id}</td>
                    <td style={{ border: '1px solid #ccc', padding: '8px' }}>{device.name}</td>
                    <td style={{ border: '1px solid #ccc', padding: '8px' }}>{device.model}</td>
                    <td
                      style={{
                        border: '1px solid #ccc',
                        padding: '8px',
                        color:
                          device.status === DeviceStatus.ONLINE
                            ? 'green'
                            : device.status === DeviceStatus.OFFLINE
                              ? 'red'
                              : 'orange',
                      }}
                    >
                      {device.status}
                    </td>
                    <td style={{ border: '1px solid #ccc', padding: '8px' }}>
                      {new Date(device.lastSeen).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Send Command */}
      <div style={{ marginBottom: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h2>Send Test Command</h2>
        <button
          onClick={handleSendTestCommand}
          disabled={!selectedDeviceId || commandLoading}
          style={{
            padding: '10px 20px',
            fontSize: '16px',
            cursor: !selectedDeviceId || commandLoading ? 'not-allowed' : 'pointer',
          }}
        >
          {commandLoading ? 'Sending...' : 'Send Shell Command'}
        </button>

        {commandError && <p style={{ color: 'red' }}>Error: {commandError}</p>}
        {commandResult && <p style={{ color: 'blue' }}>{commandResult}</p>}
      </div>

      {/* Notifications */}
      <div style={{ marginBottom: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h2>Notifications ({notifications.length})</h2>
        {notifications.length === 0 && <p>No notifications</p>}

        {notifications.map((notif) => (
          <div
            key={notif.id}
            style={{
              padding: '10px',
              margin: '5px 0',
              border: '1px solid #ccc',
              backgroundColor:
                notif.level === 'error'
                  ? '#ffebee'
                  : notif.level === 'success'
                    ? '#e8f5e9'
                    : notif.level === 'warning'
                      ? '#fff3e0'
                      : '#e3f2fd',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div>
                {notif.title && <strong>{notif.title}: </strong>}
                {notif.message}
              </div>
              <button onClick={() => removeNotification(notif.id)}>×</button>
            </div>
            <small style={{ color: '#666' }}>
              {new Date(notif.timestamp).toLocaleTimeString()}
            </small>
          </div>
        ))}
      </div>

      {/* Debug Info */}
      <div style={{ marginBottom: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h2>Debug Info</h2>
        <pre style={{ fontSize: '12px', overflow: 'auto' }}>
          {JSON.stringify(
            {
              isConnected,
              status,
              devicesCount: devices.length,
              selectedDeviceId,
              notificationsCount: notifications.length,
            },
            null,
            2
          )}
        </pre>
      </div>
    </div>
  );
}
