import { useCallback } from 'react';
import toast from 'react-hot-toast';
import { useNotificationStore, type NotificationType, type NotificationAction } from '../stores/notificationStore';

interface NotifyOptions {
  title?: string;
  duration?: number;
  action?: NotificationAction;
  deviceId?: string;
  category?: 'device' | 'command' | 'system' | 'security';
  priority?: number;
  sound?: boolean;
}

interface NotificationAPI {
  success: (message: string, options?: NotifyOptions) => void;
  error: (message: string, options?: NotifyOptions) => void;
  warning: (message: string, options?: NotifyOptions) => void;
  info: (message: string, options?: NotifyOptions) => void;
  critical: (message: string, options?: NotifyOptions) => void;
}

export function useNotification(): { notify: NotificationAPI } {
  const addNotification = useNotificationStore((state) => state.addNotification);
  const settings = useNotificationStore((state) => state.settings);

  const playSound = useCallback((type: NotificationType) => {
    if (!settings.soundEnabled || settings.doNotDisturb) return;

    try {
      const soundMap: Record<NotificationType, string> = {
        success: '/sounds/success.mp3',
        error: '/sounds/error.mp3',
        warning: '/sounds/warning.mp3',
        info: '/sounds/info.mp3',
        critical: '/sounds/critical.mp3',
      };

      const audio = new Audio(soundMap[type]);
      audio.volume = settings.volume;
      audio.play().catch(() => {
        // Silent fail if audio doesn't load
      });
    } catch {
      // Silent fail
    }
  }, [settings.soundEnabled, settings.doNotDisturb, settings.volume]);

  const showBrowserNotification = useCallback(async (
    title: string,
    body: string,
    type: NotificationType
  ) => {
    if (!settings.browserPushEnabled || settings.doNotDisturb) return;
    if (!('Notification' in window)) return;
    
    if (Notification.permission === 'granted') {
      const icon = `/icons/notification-${type}.png`;
      new Notification(title, {
        body,
        icon,
        badge: '/icons/badge.png',
        tag: 'eaglespy-notification',
      });
    } else if (Notification.permission !== 'denied') {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        const icon = `/icons/notification-${type}.png`;
        new Notification(title, {
          body,
          icon,
          badge: '/icons/badge.png',
          tag: 'eaglespy-notification',
        });
      }
    }
  }, [settings.browserPushEnabled, settings.doNotDisturb]);

  const createNotification = useCallback((
    type: NotificationType,
    message: string,
    options: NotifyOptions = {}
  ) => {
    if (!settings.enabled || settings.doNotDisturb) return;

    const {
      title,
      duration,
      action,
      deviceId,
      category,
      priority,
      sound = true,
    } = options;

    // Add to notification store
    const id = addNotification({
      type,
      title,
      message,
      priority: priority ?? (type === 'critical' ? 5 : 3),
      action,
      deviceId,
      category,
    });

    // Determine auto-dismiss duration
    const autoDismissDuration: number = duration !== undefined ? duration : (settings.autoDismissTiming[type] || 4000);

    // Show toast notification
    const toastOptions = {
      duration: autoDismissDuration,
      id,
      icon: getIconForType(type),
      className: getToastClassName(type),
    };

    if (action) {
      toast.custom((t) => (
        <div
          className={`
            flex items-center gap-3 p-4 rounded-lg
            glass-dark border shadow-glass
            min-w-[300px] max-w-md
            ${getToastBorderColor(type)}
            ${t.visible ? 'animate-slide-in' : 'animate-slide-out'}
          `}
        >
          <div className="flex-shrink-0">{getIconForType(type)}</div>
          <div className="flex-1">
            {title && <p className="font-semibold text-white mb-1">{title}</p>}
            <p className="text-white/80 text-sm">{message}</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                action.onClick();
                toast.dismiss(t.id);
              }}
              className="px-3 py-1 text-sm bg-electric-500 hover:bg-electric-600 text-dark rounded transition-colors"
            >
              {action.label}
            </button>
            <button
              onClick={() => toast.dismiss(t.id)}
              className="p-1 rounded hover:bg-white/10 transition-colors"
            >
              <svg className="w-4 h-4 text-white/60" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      ), toastOptions);
    } else {
      const toastMessage = title ? `${title}: ${message}` : message;
      
      // Use appropriate toast method based on type
      if (type === 'critical' || type === 'error') {
        toast.error(toastMessage, toastOptions);
      } else if (type === 'success') {
        toast.success(toastMessage, toastOptions);
      } else {
        toast(toastMessage, toastOptions);
      }
    }

    // Play sound
    if (sound) {
      playSound(type);
    }

    // Show browser notification if tab is not active
    if (document.hidden && title) {
      showBrowserNotification(title, message, type);
    }

    return id;
  }, [settings, addNotification, playSound, showBrowserNotification]);

  const notify: NotificationAPI = {
    success: (message, options) => createNotification('success', message, options),
    error: (message, options) => createNotification('error', message, options),
    warning: (message, options) => createNotification('warning', message, options),
    info: (message, options) => createNotification('info', message, options),
    critical: (message, options) => createNotification('critical', message, { ...options, priority: 5 }),
  };

  return { notify };
}

function getIconForType(type: NotificationType) {
  const icons = {
    success: (
      <svg className="w-5 h-5 text-neon-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
      </svg>
    ),
    error: (
      <svg className="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
      </svg>
    ),
    warning: (
      <svg className="w-5 h-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
      </svg>
    ),
    info: (
      <svg className="w-5 h-5 text-electric-500" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
      </svg>
    ),
    critical: (
      <svg className="w-5 h-5 text-red-600 animate-pulse" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
      </svg>
    ),
  };
  return icons[type];
}

function getToastClassName(type: NotificationType): string {
  const classes = {
    success: 'toast-success',
    error: 'toast-error',
    warning: 'toast-warning',
    info: 'toast-info',
    critical: 'toast-critical',
  };
  return classes[type];
}

function getToastBorderColor(type: NotificationType): string {
  const colors = {
    success: 'border-neon-500',
    error: 'border-red-500',
    warning: 'border-yellow-500',
    info: 'border-electric-500',
    critical: 'border-red-600',
  };
  return colors[type];
}
