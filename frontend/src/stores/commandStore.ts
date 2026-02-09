import { create } from 'zustand';
import type {
  Command,
  SendCommandRequest,
  WebSocketMessage,
} from '../types/api';
import {
  CommandStatus,
  WebSocketMessageType,
} from '../types/api';
import { getWebSocketService } from '../services/websocket';
import { getApiService } from '../services/api';

interface CommandState {
  commands: Map<string, Command>;
  pendingCommands: Set<string>;
  loading: boolean;
  error: string | null;
}

interface CommandActions {
  // Fetch commands from API
  fetchCommands: (deviceId?: string) => Promise<void>;
  fetchCommand: (id: string) => Promise<void>;

  // Send command with optimistic update
  sendCommand: (request: SendCommandRequest) => Promise<Command | null>;
  cancelCommand: (id: string) => Promise<void>;

  // CRUD operations
  addCommand: (command: Command) => void;
  updateCommand: (id: string, updates: Partial<Command>) => void;
  removeCommand: (id: string) => void;
  setCommandStatus: (id: string, status: CommandStatus) => void;

  // Optimistic updates
  addOptimisticCommand: (command: Command) => void;
  rollbackOptimisticCommand: (id: string) => void;

  // Utilities
  getCommand: (id: string) => Command | undefined;
  getCommandsList: () => Command[];
  getDeviceCommands: (deviceId: string) => Command[];
  getPendingCommands: () => Command[];
  clearError: () => void;

  // WebSocket integration
  handleWebSocketMessage: (message: WebSocketMessage) => void;
}

type CommandStore = CommandState & CommandActions;

export const useCommandStore = create<CommandStore>((set, get) => ({
  // Initial state
  commands: new Map(),
  pendingCommands: new Set(),
  loading: false,
  error: null,

  // Fetch commands from API
  fetchCommands: async (deviceId?: string) => {
    set({ loading: true, error: null });
    try {
      const api = getApiService();
      const response = await api.getCommands(deviceId ? { deviceId } : undefined);

      if (response.success && response.data) {
        const commandsMap = new Map<string, Command>();
        const pendingSet = new Set<string>();

        response.data.forEach((command) => {
          commandsMap.set(command.id, command);
          if (
            command.status === CommandStatus.PENDING ||
            command.status === CommandStatus.SENT ||
            command.status === CommandStatus.EXECUTING
          ) {
            pendingSet.add(command.id);
          }
        });

        set({ commands: commandsMap, pendingCommands: pendingSet, loading: false });
      } else {
        set({ error: response.error || 'Failed to fetch commands', loading: false });
      }
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to fetch commands',
        loading: false,
      });
    }
  },

  fetchCommand: async (id: string) => {
    set({ loading: true, error: null });
    try {
      const api = getApiService();
      const response = await api.getCommand(id);

      if (response.success && response.data) {
        set((state) => {
          const newCommands = new Map(state.commands);
          newCommands.set(id, response.data);
          return { commands: newCommands, loading: false };
        });
      } else {
        set({ error: response.error || 'Failed to fetch command', loading: false });
      }
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to fetch command',
        loading: false,
      });
    }
  },

  // Send command with optimistic update
  sendCommand: async (request: SendCommandRequest) => {
    const tempId = `temp_${Date.now()}`;
    const optimisticCommand: Command = {
      id: tempId,
      deviceId: request.deviceId,
      type: request.type,
      payload: request.payload,
      status: CommandStatus.PENDING,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // Add optimistic command
    get().addOptimisticCommand(optimisticCommand);

    try {
      const api = getApiService();
      const response = await api.sendCommand(request);

      if (response.success && response.data) {
        // Replace optimistic command with real one
        set((state) => {
          const newCommands = new Map(state.commands);
          newCommands.delete(tempId);
          newCommands.set(response.data.id, response.data);

          const newPending = new Set(state.pendingCommands);
          newPending.delete(tempId);
          newPending.add(response.data.id);

          return { commands: newCommands, pendingCommands: newPending, error: null };
        });

        return response.data;
      } else {
        // Rollback on error
        get().rollbackOptimisticCommand(tempId);
        set({ error: response.error || 'Failed to send command' });
        return null;
      }
    } catch (error) {
      // Rollback on error
      get().rollbackOptimisticCommand(tempId);
      set({ error: error instanceof Error ? error.message : 'Failed to send command' });
      return null;
    }
  },

  cancelCommand: async (id: string) => {
    const originalStatus = get().commands.get(id)?.status;

    // Optimistic update
    get().setCommandStatus(id, CommandStatus.CANCELLED);

    try {
      const api = getApiService();
      const response = await api.cancelCommand(id);

      if (response.success && response.data) {
        get().updateCommand(id, response.data);
      } else {
        // Rollback on error
        if (originalStatus) {
          get().setCommandStatus(id, originalStatus);
        }
        set({ error: response.error || 'Failed to cancel command' });
      }
    } catch (error) {
      // Rollback on error
      if (originalStatus) {
        get().setCommandStatus(id, originalStatus);
      }
      set({ error: error instanceof Error ? error.message : 'Failed to cancel command' });
    }
  },

  // Add a new command
  addCommand: (command: Command) => {
    set((state) => {
      const newCommands = new Map(state.commands);
      newCommands.set(command.id, command);

      const newPending = new Set(state.pendingCommands);
      if (
        command.status === CommandStatus.PENDING ||
        command.status === CommandStatus.SENT ||
        command.status === CommandStatus.EXECUTING
      ) {
        newPending.add(command.id);
      }

      return { commands: newCommands, pendingCommands: newPending };
    });
  },

  // Update command with partial data
  updateCommand: (id: string, updates: Partial<Command>) => {
    set((state) => {
      const command = state.commands.get(id);
      if (!command) return state;

      const newCommands = new Map(state.commands);
      const updatedCommand = { ...command, ...updates, updatedAt: new Date().toISOString() };
      newCommands.set(id, updatedCommand);

      const newPending = new Set(state.pendingCommands);
      const isPending =
        updatedCommand.status === CommandStatus.PENDING ||
        updatedCommand.status === CommandStatus.SENT ||
        updatedCommand.status === CommandStatus.EXECUTING;

      if (isPending) {
        newPending.add(id);
      } else {
        newPending.delete(id);
      }

      return { commands: newCommands, pendingCommands: newPending };
    });
  },

  // Remove a command
  removeCommand: (id: string) => {
    set((state) => {
      const newCommands = new Map(state.commands);
      newCommands.delete(id);

      const newPending = new Set(state.pendingCommands);
      newPending.delete(id);

      return { commands: newCommands, pendingCommands: newPending };
    });
  },

  // Update command status
  setCommandStatus: (id: string, status: CommandStatus) => {
    get().updateCommand(id, { status });
  },

  // Optimistic updates
  addOptimisticCommand: (command: Command) => {
    set((state) => {
      const newCommands = new Map(state.commands);
      newCommands.set(command.id, command);

      const newPending = new Set(state.pendingCommands);
      newPending.add(command.id);

      return { commands: newCommands, pendingCommands: newPending };
    });
  },

  rollbackOptimisticCommand: (id: string) => {
    get().removeCommand(id);
  },

  // Get a specific command
  getCommand: (id: string) => {
    return get().commands.get(id);
  },

  // Get all commands as array
  getCommandsList: () => {
    return Array.from(get().commands.values());
  },

  // Get commands for a specific device
  getDeviceCommands: (deviceId: string) => {
    return Array.from(get().commands.values()).filter((cmd) => cmd.deviceId === deviceId);
  },

  // Get pending commands
  getPendingCommands: () => {
    const state = get();
    return Array.from(state.pendingCommands)
      .map((id) => state.commands.get(id))
      .filter((cmd): cmd is Command => cmd !== undefined);
  },

  // Clear error
  clearError: () => {
    set({ error: null });
  },

  // Handle WebSocket messages
  handleWebSocketMessage: (message: WebSocketMessage) => {
    const { type, payload } = message;

    switch (type) {
      case WebSocketMessageType.COMMAND_RECEIVED: {
        const command = payload as Command;
        get().addCommand(command);
        console.log('Command received:', command.id);
        break;
      }

      case WebSocketMessageType.COMMAND_COMPLETED: {
        const { commandId, status, result } = payload as {
          commandId: string;
          status: CommandStatus;
          result?: Command['result'];
        };
        get().updateCommand(commandId, {
          status,
          result,
          executedAt: new Date().toISOString(),
        });
        console.log('Command completed:', commandId);
        break;
      }

      case WebSocketMessageType.COMMAND_FAILED: {
        const { commandId, status, result } = payload as {
          commandId: string;
          status: CommandStatus;
          result?: Command['result'];
        };
        get().updateCommand(commandId, {
          status,
          result,
          executedAt: new Date().toISOString(),
        });
        console.log('Command failed:', commandId);
        break;
      }

      default:
        break;
    }
  },
}));

// Initialize WebSocket listener
export function initializeCommandWebSocket() {
  const ws = getWebSocketService();

  // Subscribe to commands channel
  ws.subscribe('CommandsChannel');

  // Listen to all WebSocket messages
  const unsubscribe = ws.onMessage((message) => {
    useCommandStore.getState().handleWebSocketMessage(message);
  });

  return unsubscribe;
}
