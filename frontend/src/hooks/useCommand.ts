import { useCallback } from 'react';
import { useCommandStore } from '../stores/commandStore';
import { initializeCommandWebSocket } from '../stores/commandStore';
import { CommandType, type SendCommandRequest } from '../types/api';
import { useEffect } from 'react';

export function useCommand() {
  const sendCommand = useCommandStore((state) => state.sendCommand);
  const cancelCommand = useCommandStore((state) => state.cancelCommand);
  const loading = useCommandStore((state) => state.loading);
  const error = useCommandStore((state) => state.error);
  const clearError = useCommandStore((state) => state.clearError);

  useEffect(() => {
    // Initialize WebSocket connection for commands
    const unsubscribe = initializeCommandWebSocket();

    return () => {
      unsubscribe();
    };
  }, []);

  const execute = useCallback(
    async (deviceId: string, type: CommandType, payload?: Record<string, unknown>) => {
      const request: SendCommandRequest = {
        deviceId,
        type,
        payload,
      };
      return await sendCommand(request);
    },
    [sendCommand]
  );

  const cancel = useCallback(
    async (commandId: string) => {
      return await cancelCommand(commandId);
    },
    [cancelCommand]
  );

  return {
    execute,
    cancel,
    loading,
    error,
    clearError,
  };
}

export function useCommands(deviceId?: string) {
  const commands = useCommandStore(
    useCallback(
      (state) => {
        if (deviceId) {
          return state.getDeviceCommands(deviceId);
        }
        return state.getCommandsList();
      },
      [deviceId]
    )
  );

  const loading = useCommandStore((state) => state.loading);
  const error = useCommandStore((state) => state.error);
  const fetchCommands = useCommandStore((state) => state.fetchCommands);
  const clearError = useCommandStore((state) => state.clearError);

  useEffect(() => {
    fetchCommands(deviceId);
  }, [deviceId, fetchCommands]);

  const refresh = useCallback(() => {
    return fetchCommands(deviceId);
  }, [deviceId, fetchCommands]);

  return {
    commands,
    loading,
    error,
    refresh,
    clearError,
  };
}

export function useCommandHistory(deviceId: string) {
  const commands = useCommandStore((state) => state.getDeviceCommands(deviceId));

  // Sort by creation time, most recent first
  const sortedCommands = [...commands].sort((a, b) => {
    return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
  });

  return {
    commands: sortedCommands,
    count: commands.length,
  };
}

export function usePendingCommands() {
  const pendingCommands = useCommandStore((state) => state.getPendingCommands());

  return {
    pendingCommands,
    count: pendingCommands.length,
    hasPending: pendingCommands.length > 0,
  };
}

export function useCommandById(commandId: string | null) {
  const command = useCommandStore(
    useCallback((state) => (commandId ? state.getCommand(commandId) : null), [commandId])
  );
  const loading = useCommandStore((state) => state.loading);
  const error = useCommandStore((state) => state.error);
  const fetchCommand = useCommandStore((state) => state.fetchCommand);
  const clearError = useCommandStore((state) => state.clearError);

  useEffect(() => {
    if (commandId) {
      fetchCommand(commandId);
    }
  }, [commandId, fetchCommand]);

  const refresh = useCallback(() => {
    if (commandId) {
      return fetchCommand(commandId);
    }
  }, [commandId, fetchCommand]);

  return {
    command,
    loading,
    error,
    refresh,
    clearError,
  };
}
