import { useEffect } from 'react';
import { useWebSocket } from '../hooks/useWebSocket';
import { useNotification } from '../hooks/useNotification';
import type { WebSocketMessage } from '../types/api';
import { WebSocketMessageType } from '../types/api';

/**
 * Service that listens to WebSocket events and creates notifications
 */
export function useNotificationService() {
  const { onMessage } = useWebSocket();
  const { notify } = useNotification();

  useEffect(() => {
    const unsubscribe = onMessage((message: WebSocketMessage) => {
      handleWebSocketMessage(message);
    });

    return unsubscribe;
  }, [onMessage, notify]);

  function handleWebSocketMessage(message: WebSocketMessage) {
    const { type, payload } = message;
    const data = payload as any;

    // Device events
    if (type === WebSocketMessageType.DEVICE_CONNECTED || 
        type === WebSocketMessageType.DEVICE_DISCONNECTED ||
        type === WebSocketMessageType.DEVICE_STATUS_UPDATED) {
      handleDeviceEvent(data);
    }

    // Command events
    if (type === WebSocketMessageType.COMMAND_COMPLETED || 
        type === WebSocketMessageType.COMMAND_FAILED) {
      handleCommandEvent(data);
    }

    // System/error events
    if (type === WebSocketMessageType.ERROR || type === WebSocketMessageType.NOTIFICATION) {
      handleSystemEvent(data);
    }
  }

  function handleDeviceEvent(data: any) {
    const { event, device } = data || {};

    switch (event) {
      case 'device_connected':
        notify.success(`Device connected: ${device?.name || 'Unknown'}`, {
          title: 'Device Connected',
          category: 'device',
          deviceId: device?.id,
        });
        break;

      case 'device_disconnected':
        notify.warning(`Device disconnected: ${device?.name || 'Unknown'}`, {
          title: 'Device Disconnected',
          category: 'device',
          deviceId: device?.id,
        });
        break;

      case 'device_updated':
        notify.info(`Device updated: ${device?.name || 'Unknown'}`, {
          title: 'Device Updated',
          category: 'device',
          deviceId: device?.id,
          priority: 2,
        });
        break;

      case 'new_data':
        notify.info(`New data from ${device?.name || 'device'}`, {
          title: 'New Data Available',
          category: 'device',
          deviceId: device?.id,
          priority: 3,
        });
        break;

      default:
        break;
    }
  }

  function handleCommandEvent(data: any) {
    const { event, command } = data || {};

    switch (event) {
      case 'command_sent':
        notify.info(`Command sent: ${command?.name || 'Unknown'}`, {
          title: 'Command Sent',
          category: 'command',
        });
        break;

      case 'command_completed':
        notify.success(`Command completed: ${command?.name || 'Unknown'}`, {
          title: 'Command Completed',
          category: 'command',
        });
        break;

      case 'command_failed':
        notify.error(`Command failed: ${command?.name || 'Unknown'}`, {
          title: 'Command Failed',
          category: 'command',
          action: command?.retry
            ? {
                label: 'Retry',
                onClick: command.retry,
              }
            : undefined,
        });
        break;

      case 'command_timeout':
        notify.warning(`Command timeout: ${command?.name || 'Unknown'}`, {
          title: 'Command Timeout',
          category: 'command',
        });
        break;

      default:
        break;
    }
  }

  function handleSystemEvent(data: any) {
    const { event, message, level } = data || {};

    switch (level || 'info') {
      case 'critical':
        notify.critical(message || event || 'System event', {
          title: 'Critical System Event',
          category: 'system',
        });
        break;

      case 'error':
        notify.error(message || event || 'System event', {
          title: 'System Error',
          category: 'system',
        });
        break;

      case 'warning':
        notify.warning(message || event || 'System event', {
          title: 'System Warning',
          category: 'system',
        });
        break;

      default:
        notify.info(message || event || 'System event', {
          title: 'System Event',
          category: 'system',
          priority: 2,
        });
        break;
    }
  }
}
