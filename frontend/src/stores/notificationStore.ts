import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type NotificationType = 'info' | 'success' | 'warning' | 'error' | 'critical';

export interface NotificationAction {
  label: string;
  onClick: () => void;
}

export interface Notification {
  id: string;
  type: NotificationType;
  title?: string;
  message: string;
  timestamp: Date;
  read: boolean;
  priority: number; // 1-5, 5 being highest
  action?: NotificationAction;
  deviceId?: string;
  category?: 'device' | 'command' | 'system' | 'security';
}

interface NotificationSettings {
  enabled: boolean;
  soundEnabled: boolean;
  doNotDisturb: boolean;
  browserPushEnabled: boolean;
  volume: number; // 0-1
  autoDismissTiming: {
    info: number;
    success: number;
    warning: number;
    error: number;
    critical: number;
  };
}

interface NotificationState {
  notifications: Notification[];
  settings: NotificationSettings;
  unreadCount: number;
}

interface NotificationActions {
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => string;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  removeNotification: (id: string) => void;
  clearAll: () => void;
  clearOlderThan: (days: number) => void;
  
  // Settings
  updateSettings: (settings: Partial<NotificationSettings>) => void;
  toggleSound: () => void;
  toggleDoNotDisturb: () => void;
  toggleBrowserPush: () => void;
  setVolume: (volume: number) => void;
  
  // Filters
  getUnreadNotifications: () => Notification[];
  getNotificationsByType: (type: NotificationType) => Notification[];
  getNotificationsByCategory: (category: Notification['category']) => Notification[];
  getTodayNotifications: () => Notification[];
  getYesterdayNotifications: () => Notification[];
  getOlderNotifications: () => Notification[];
}

type NotificationStore = NotificationState & NotificationActions;

const defaultSettings: NotificationSettings = {
  enabled: true,
  soundEnabled: true,
  doNotDisturb: false,
  browserPushEnabled: false,
  volume: 0.5,
  autoDismissTiming: {
    info: 4000,
    success: 3000,
    warning: 5000,
    error: 6000,
    critical: 0, // Never auto-dismiss
  },
};

export const useNotificationStore = create<NotificationStore>()(
  persist(
    (set, get) => ({
      // Initial state
      notifications: [],
      settings: defaultSettings,
      unreadCount: 0,

      // Actions
      addNotification: (notification) => {
        const id = `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const newNotification: Notification = {
          ...notification,
          id,
          timestamp: new Date(),
          read: false,
          priority: notification.priority ?? (notification.type === 'critical' ? 5 : 3),
        };

        set((state) => ({
          notifications: [newNotification, ...state.notifications],
          unreadCount: state.unreadCount + 1,
        }));

        return id;
      },

      markAsRead: (id) => {
        set((state) => {
          const notification = state.notifications.find((n) => n.id === id);
          if (!notification || notification.read) return state;

          return {
            notifications: state.notifications.map((n) =>
              n.id === id ? { ...n, read: true } : n
            ),
            unreadCount: Math.max(0, state.unreadCount - 1),
          };
        });
      },

      markAllAsRead: () => {
        set((state) => ({
          notifications: state.notifications.map((n) => ({ ...n, read: true })),
          unreadCount: 0,
        }));
      },

      removeNotification: (id) => {
        set((state) => {
          const notification = state.notifications.find((n) => n.id === id);
          const wasUnread = notification && !notification.read;

          return {
            notifications: state.notifications.filter((n) => n.id !== id),
            unreadCount: wasUnread ? Math.max(0, state.unreadCount - 1) : state.unreadCount,
          };
        });
      },

      clearAll: () => {
        set({ notifications: [], unreadCount: 0 });
      },

      clearOlderThan: (days) => {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - days);

        set((state) => {
          const filtered = state.notifications.filter(
            (n) => new Date(n.timestamp) > cutoffDate
          );
          const removedUnread = state.notifications.filter(
            (n) => new Date(n.timestamp) <= cutoffDate && !n.read
          ).length;

          return {
            notifications: filtered,
            unreadCount: Math.max(0, state.unreadCount - removedUnread),
          };
        });
      },

      // Settings
      updateSettings: (newSettings) => {
        set((state) => ({
          settings: { ...state.settings, ...newSettings },
        }));
      },

      toggleSound: () => {
        set((state) => ({
          settings: { ...state.settings, soundEnabled: !state.settings.soundEnabled },
        }));
      },

      toggleDoNotDisturb: () => {
        set((state) => ({
          settings: { ...state.settings, doNotDisturb: !state.settings.doNotDisturb },
        }));
      },

      toggleBrowserPush: () => {
        set((state) => ({
          settings: { ...state.settings, browserPushEnabled: !state.settings.browserPushEnabled },
        }));
      },

      setVolume: (volume) => {
        set((state) => ({
          settings: { ...state.settings, volume: Math.max(0, Math.min(1, volume)) },
        }));
      },

      // Filters
      getUnreadNotifications: () => {
        return get().notifications.filter((n) => !n.read);
      },

      getNotificationsByType: (type) => {
        return get().notifications.filter((n) => n.type === type);
      },

      getNotificationsByCategory: (category) => {
        return get().notifications.filter((n) => n.category === category);
      },

      getTodayNotifications: () => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return get().notifications.filter((n) => new Date(n.timestamp) >= today);
      },

      getYesterdayNotifications: () => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        return get().notifications.filter((n) => {
          const timestamp = new Date(n.timestamp);
          return timestamp >= yesterday && timestamp < today;
        });
      },

      getOlderNotifications: () => {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        yesterday.setHours(0, 0, 0, 0);
        return get().notifications.filter((n) => new Date(n.timestamp) < yesterday);
      },
    }),
    {
      name: 'notification-storage',
      partialize: (state) => ({
        notifications: state.notifications.slice(0, 100), // Keep last 100 notifications
        settings: state.settings,
      }),
    }
  )
);
