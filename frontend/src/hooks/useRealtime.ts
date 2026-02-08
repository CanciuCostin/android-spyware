import { useEffect } from 'react';
import { useWebSocket } from './useWebSocket';
import type { WebSocketMessage } from '../types/api';
import { WebSocketMessageType } from '../types/api';
import { useUIStore } from '../stores/uiStore';

export function useRealtime() {
  const { isConnected, status, onMessage } = useWebSocket();
  const addNotification = useUIStore((state) => state.addNotification);

  useEffect(() => {
    const unsubscribe = onMessage((message: WebSocketMessage) => {
      // Handle generic notifications
      if (message.type === WebSocketMessageType.NOTIFICATION) {
        const notif = message.payload as {
          level: 'info' | 'warning' | 'error' | 'success';
          message: string;
          title?: string;
          duration?: number;
        };
        addNotification(notif);
      }

      // Handle errors
      if (message.type === WebSocketMessageType.ERROR) {
        const error = message.payload as { message: string; code?: string };
        addNotification({
          level: 'error',
          message: error.message,
          title: 'Error',
        });
      }
    });

    return () => {
      unsubscribe();
    };
  }, [onMessage, addNotification]);

  return {
    isConnected,
    status,
  };
}

export function useRealtimeUpdates<T>(
  messageType: WebSocketMessageType,
  callback: (payload: T) => void
) {
  const { onMessage } = useWebSocket();

  useEffect(() => {
    const unsubscribe = onMessage((message: WebSocketMessage) => {
      if (message.type === messageType) {
        callback(message.payload as T);
      }
    });

    return () => {
      unsubscribe();
    };
  }, [messageType, callback, onMessage]);
}

export function useRealtimeDeviceUpdates(
  deviceId: string | null,
  callback: (payload: unknown) => void
) {
  const { onMessage } = useWebSocket();

  useEffect(() => {
    if (!deviceId) return;

    const unsubscribe = onMessage((message: WebSocketMessage) => {
      // Filter messages for this specific device
      if (
        message.type === WebSocketMessageType.DEVICE_STATUS_UPDATED ||
        message.type === WebSocketMessageType.DEVICE_CONNECTED ||
        message.type === WebSocketMessageType.DEVICE_DISCONNECTED
      ) {
        const payload = message.payload as { deviceId?: string };
        if (payload.deviceId === deviceId) {
          callback(payload);
        }
      }
    });

    return () => {
      unsubscribe();
    };
  }, [deviceId, callback, onMessage]);
}

export function useRealtimeCommandUpdates(
  commandId: string | null,
  callback: (payload: unknown) => void
) {
  const { onMessage } = useWebSocket();

  useEffect(() => {
    if (!commandId) return;

    const unsubscribe = onMessage((message: WebSocketMessage) => {
      // Filter messages for this specific command
      if (
        message.type === WebSocketMessageType.COMMAND_COMPLETED ||
        message.type === WebSocketMessageType.COMMAND_FAILED
      ) {
        const payload = message.payload as { commandId?: string };
        if (payload.commandId === commandId) {
          callback(payload);
        }
      }
    });

    return () => {
      unsubscribe();
    };
  }, [commandId, callback, onMessage]);
}
