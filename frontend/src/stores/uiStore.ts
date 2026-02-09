import { create } from 'zustand';
import { ConnectionStatus, type NotificationMessage } from '../types/api';

interface Notification extends NotificationMessage {
  id: string;
  timestamp: string;
}

interface UIState {
  connectionStatus: ConnectionStatus;
  notifications: Notification[];
  loading: Map<string, boolean>;
  errors: Map<string, string>;
}

interface UIActions {
  // Connection status
  setConnectionStatus: (status: ConnectionStatus) => void;
  isConnected: () => boolean;

  // Notifications
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp'>) => string;
  removeNotification: (id: string) => void;
  clearNotifications: () => void;

  // Loading states
  setLoading: (key: string, loading: boolean) => void;
  isLoading: (key: string) => boolean;
  clearLoading: () => void;

  // Error handling
  setError: (key: string, error: string) => void;
  clearError: (key: string) => void;
  getError: (key: string) => string | undefined;
  clearAllErrors: () => void;
}

type UIStore = UIState & UIActions;

export const useUIStore = create<UIStore>((set, get) => ({
  // Initial state
  connectionStatus: ConnectionStatus.DISCONNECTED,
  notifications: [],
  loading: new Map(),
  errors: new Map(),

  // Connection status
  setConnectionStatus: (status: ConnectionStatus) => {
    set({ connectionStatus: status });

    // Auto-notification for connection changes
    const statusMessages: Record<ConnectionStatus, string> = {
      [ConnectionStatus.CONNECTING]: 'Connecting to server...',
      [ConnectionStatus.CONNECTED]: 'Connected to server',
      [ConnectionStatus.DISCONNECTED]: 'Disconnected from server',
      [ConnectionStatus.RECONNECTING]: 'Reconnecting to server...',
      [ConnectionStatus.ERROR]: 'Connection error',
    };

    const statusLevels: Record<ConnectionStatus, NotificationMessage['level']> = {
      [ConnectionStatus.CONNECTING]: 'info',
      [ConnectionStatus.CONNECTED]: 'success',
      [ConnectionStatus.DISCONNECTED]: 'warning',
      [ConnectionStatus.RECONNECTING]: 'info',
      [ConnectionStatus.ERROR]: 'error',
    };

    get().addNotification({
      level: statusLevels[status],
      message: statusMessages[status],
      duration: status === ConnectionStatus.CONNECTED ? 3000 : undefined,
    });
  },

  isConnected: () => {
    return get().connectionStatus === ConnectionStatus.CONNECTED;
  },

  // Notifications
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp'>) => {
    const id = `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const newNotification: Notification = {
      ...notification,
      id,
      timestamp: new Date().toISOString(),
    };

    set((state) => ({
      notifications: [...state.notifications, newNotification],
    }));

    // Auto-remove after duration
    if (notification.duration) {
      setTimeout(() => {
        get().removeNotification(id);
      }, notification.duration);
    }

    return id;
  },

  removeNotification: (id: string) => {
    set((state) => ({
      notifications: state.notifications.filter((n) => n.id !== id),
    }));
  },

  clearNotifications: () => {
    set({ notifications: [] });
  },

  // Loading states
  setLoading: (key: string, loading: boolean) => {
    set((state) => {
      const newLoading = new Map(state.loading);
      if (loading) {
        newLoading.set(key, true);
      } else {
        newLoading.delete(key);
      }
      return { loading: newLoading };
    });
  },

  isLoading: (key: string) => {
    return get().loading.get(key) || false;
  },

  clearLoading: () => {
    set({ loading: new Map() });
  },

  // Error handling
  setError: (key: string, error: string) => {
    set((state) => {
      const newErrors = new Map(state.errors);
      newErrors.set(key, error);
      return { errors: newErrors };
    });

    // Also show as notification
    get().addNotification({
      level: 'error',
      message: error,
      title: 'Error',
    });
  },

  clearError: (key: string) => {
    set((state) => {
      const newErrors = new Map(state.errors);
      newErrors.delete(key);
      return { errors: newErrors };
    });
  },

  getError: (key: string) => {
    return get().errors.get(key);
  },

  clearAllErrors: () => {
    set({ errors: new Map() });
  },
}));

// Helper hook for managing loading states
export function useLoadingState(key: string) {
  const isLoading = useUIStore((state) => state.isLoading(key));
  const setLoading = useUIStore((state) => state.setLoading);

  const startLoading = () => setLoading(key, true);
  const stopLoading = () => setLoading(key, false);

  return { isLoading, startLoading, stopLoading };
}

// Helper hook for managing errors
export function useErrorState(key: string) {
  const error = useUIStore((state) => state.getError(key));
  const setError = useUIStore((state) => state.setError);
  const clearError = useUIStore((state) => state.clearError);

  const setErrorForKey = (error: string) => setError(key, error);
  const clearErrorForKey = () => clearError(key);

  return { error, setError: setErrorForKey, clearError: clearErrorForKey };
}
