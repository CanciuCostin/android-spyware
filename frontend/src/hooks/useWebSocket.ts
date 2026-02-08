import { useEffect, useCallback } from 'react';
import { getWebSocketService } from '../services/websocket';
import type { WebSocketMessage } from '../types/api';
import { useUIStore } from '../stores/uiStore';

export function useWebSocket() {
  const ws = getWebSocketService();
  const setConnectionStatus = useUIStore((state) => state.setConnectionStatus);

  useEffect(() => {
    // Connect on mount
    ws.connect();

    // Listen to connection status changes
    const unsubscribeStatus = ws.onStatusChange((status) => {
      setConnectionStatus(status);
    });

    // Cleanup on unmount
    return () => {
      unsubscribeStatus();
      // Note: We don't disconnect here to keep connection alive across component remounts
    };
  }, [ws, setConnectionStatus]);

  const connect = useCallback(() => {
    ws.connect();
  }, [ws]);

  const disconnect = useCallback(() => {
    ws.disconnect();
  }, [ws]);

  const subscribe = useCallback(
    (channel: string, params?: Record<string, unknown>) => {
      return ws.subscribe(channel, params);
    },
    [ws]
  );

  const unsubscribe = useCallback(
    (channel: string) => {
      ws.unsubscribe(channel);
    },
    [ws]
  );

  const send = useCallback(
    (channel: string, action: string, data?: object) => {
      ws.send(channel, action, data);
    },
    [ws]
  );

  const onMessage = useCallback(
    (handler: (message: WebSocketMessage) => void) => {
      return ws.onMessage(handler);
    },
    [ws]
  );

  const status = ws.getStatus();
  const isConnected = ws.isConnected();

  return {
    connect,
    disconnect,
    subscribe,
    unsubscribe,
    send,
    onMessage,
    status,
    isConnected,
  };
}
