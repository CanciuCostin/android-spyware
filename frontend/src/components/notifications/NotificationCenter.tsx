import React, { useState, useMemo } from 'react';
import { useNotificationStore, type Notification, type NotificationType } from '../../stores/notificationStore';

interface NotificationCenterProps {
  onClose?: () => void;
}

export const NotificationCenter: React.FC<NotificationCenterProps> = ({ onClose }) => {
  const [filterType, setFilterType] = useState<NotificationType | 'all'>('all');
  
  const notifications = useNotificationStore((state) => state.notifications);
  const markAsRead = useNotificationStore((state) => state.markAsRead);
  const markAllAsRead = useNotificationStore((state) => state.markAllAsRead);
  const removeNotification = useNotificationStore((state) => state.removeNotification);
  const clearAll = useNotificationStore((state) => state.clearAll);
  const getTodayNotifications = useNotificationStore((state) => state.getTodayNotifications);
  const getYesterdayNotifications = useNotificationStore((state) => state.getYesterdayNotifications);
  const getOlderNotifications = useNotificationStore((state) => state.getOlderNotifications);

  // Filter notifications
  const filteredNotifications = useMemo(() => {
    if (filterType === 'all') return notifications;
    return notifications.filter((n) => n.type === filterType);
  }, [notifications, filterType]);

  // Group by date
  const today = useMemo(() => getTodayNotifications().filter(n => 
    filterType === 'all' || n.type === filterType
  ), [filteredNotifications, filterType]);
  
  const yesterday = useMemo(() => getYesterdayNotifications().filter(n => 
    filterType === 'all' || n.type === filterType
  ), [filteredNotifications, filterType]);
  
  const older = useMemo(() => getOlderNotifications().filter(n => 
    filterType === 'all' || n.type === filterType
  ), [filteredNotifications, filterType]);

  const hasNotifications = filteredNotifications.length > 0;

  return (
    <div className="w-96 max-h-[600px] glass-dark border border-white/20 rounded-lg shadow-glass overflow-hidden">
      {/* Header */}
      <div className="p-4 border-b border-white/10">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-lg font-semibold text-white">Notifications</h3>
          <button
            onClick={onClose}
            className="p-1 rounded hover:bg-white/10 transition-colors"
            aria-label="Close"
          >
            <svg className="w-5 h-5 text-white/60" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          </button>
        </div>

        {/* Filter Buttons */}
        <div className="flex gap-2 flex-wrap">
          <FilterButton
            label="All"
            active={filterType === 'all'}
            count={notifications.length}
            onClick={() => setFilterType('all')}
          />
          <FilterButton
            label="Info"
            active={filterType === 'info'}
            count={notifications.filter(n => n.type === 'info').length}
            onClick={() => setFilterType('info')}
            color="electric"
          />
          <FilterButton
            label="Success"
            active={filterType === 'success'}
            count={notifications.filter(n => n.type === 'success').length}
            onClick={() => setFilterType('success')}
            color="neon"
          />
          <FilterButton
            label="Warning"
            active={filterType === 'warning'}
            count={notifications.filter(n => n.type === 'warning').length}
            onClick={() => setFilterType('warning')}
            color="yellow"
          />
          <FilterButton
            label="Error"
            active={filterType === 'error'}
            count={notifications.filter(n => n.type === 'error').length}
            onClick={() => setFilterType('error')}
            color="red"
          />
        </div>

        {/* Actions */}
        {hasNotifications && (
          <div className="flex gap-2 mt-3">
            <button
              onClick={markAllAsRead}
              className="px-3 py-1 text-sm text-electric-500 hover:text-electric-400 transition-colors"
            >
              Mark all read
            </button>
            <button
              onClick={clearAll}
              className="px-3 py-1 text-sm text-red-500 hover:text-red-400 transition-colors"
            >
              Clear all
            </button>
          </div>
        )}
      </div>

      {/* Notifications List */}
      <div className="overflow-y-auto max-h-[480px]">
        {!hasNotifications ? (
          <div className="p-8 text-center">
            <svg className="w-16 h-16 mx-auto mb-3 text-white/20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
            </svg>
            <p className="text-white/60">No notifications</p>
          </div>
        ) : (
          <>
            {today.length > 0 && (
              <NotificationGroup title="Today" notifications={today} onMarkAsRead={markAsRead} onRemove={removeNotification} />
            )}
            {yesterday.length > 0 && (
              <NotificationGroup title="Yesterday" notifications={yesterday} onMarkAsRead={markAsRead} onRemove={removeNotification} />
            )}
            {older.length > 0 && (
              <NotificationGroup title="Older" notifications={older} onMarkAsRead={markAsRead} onRemove={removeNotification} />
            )}
          </>
        )}
      </div>
    </div>
  );
};

// Filter Button Component
interface FilterButtonProps {
  label: string;
  active: boolean;
  count: number;
  onClick: () => void;
  color?: 'electric' | 'neon' | 'yellow' | 'red';
}

const FilterButton: React.FC<FilterButtonProps> = ({ label, active, count, onClick, color }) => {
  const colorClasses = {
    electric: 'text-electric-500 border-electric-500',
    neon: 'text-neon-500 border-neon-500',
    yellow: 'text-yellow-500 border-yellow-500',
    red: 'text-red-500 border-red-500',
  };

  const activeClass = color ? colorClasses[color] : 'text-white border-white';

  return (
    <button
      onClick={onClick}
      className={`
        px-2 py-1 text-xs rounded border transition-all
        ${active ? activeClass : 'text-white/60 border-white/20 hover:border-white/40'}
      `}
    >
      {label} {count > 0 && `(${count})`}
    </button>
  );
};

// Notification Group Component
interface NotificationGroupProps {
  title: string;
  notifications: Notification[];
  onMarkAsRead: (id: string) => void;
  onRemove: (id: string) => void;
}

const NotificationGroup: React.FC<NotificationGroupProps> = ({ title, notifications, onMarkAsRead, onRemove }) => {
  return (
    <div className="border-b border-white/10 last:border-0">
      <div className="px-4 py-2 bg-white/5">
        <h4 className="text-xs font-semibold text-white/60 uppercase">{title}</h4>
      </div>
      {notifications.map((notification) => (
        <NotificationItem
          key={notification.id}
          notification={notification}
          onMarkAsRead={onMarkAsRead}
          onRemove={onRemove}
        />
      ))}
    </div>
  );
};

// Notification Item Component
interface NotificationItemProps {
  notification: Notification;
  onMarkAsRead: (id: string) => void;
  onRemove: (id: string) => void;
}

const NotificationItem: React.FC<NotificationItemProps> = ({ notification, onMarkAsRead, onRemove }) => {
  const typeColors = {
    info: 'text-electric-500',
    success: 'text-neon-500',
    warning: 'text-yellow-500',
    error: 'text-red-500',
    critical: 'text-red-600',
  };

  const typeIcons = {
    info: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
      </svg>
    ),
    success: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
      </svg>
    ),
    warning: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
      </svg>
    ),
    error: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
      </svg>
    ),
    critical: (
      <svg className="w-5 h-5 animate-pulse" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
      </svg>
    ),
  };

  const formatTime = (date: Date) => {
    const d = new Date(date);
    return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div
      className={`
        px-4 py-3 hover:bg-white/5 transition-colors border-l-2
        ${notification.read ? 'border-transparent' : 'border-electric-500 bg-electric-500/5'}
      `}
    >
      <div className="flex gap-3">
        <div className={`flex-shrink-0 ${typeColors[notification.type]}`}>
          {typeIcons[notification.type]}
        </div>

        <div className="flex-1 min-w-0">
          {notification.title && (
            <h5 className="font-semibold text-white mb-1">{notification.title}</h5>
          )}
          <p className="text-sm text-white/80 break-words">{notification.message}</p>
          
          {notification.action && (
            <button
              onClick={notification.action.onClick}
              className="mt-2 px-3 py-1 text-sm bg-electric-500 hover:bg-electric-600 text-dark rounded transition-colors"
            >
              {notification.action.label}
            </button>
          )}

          <div className="flex items-center gap-3 mt-2 text-xs text-white/40">
            <span>{formatTime(notification.timestamp)}</span>
            {notification.category && (
              <span className="px-2 py-0.5 rounded bg-white/10">{notification.category}</span>
            )}
          </div>
        </div>

        <div className="flex flex-col gap-1">
          {!notification.read && (
            <button
              onClick={() => onMarkAsRead(notification.id)}
              className="p-1 rounded hover:bg-white/10 transition-colors"
              title="Mark as read"
            >
              <svg className="w-4 h-4 text-white/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </button>
          )}
          <button
            onClick={() => onRemove(notification.id)}
            className="p-1 rounded hover:bg-white/10 transition-colors"
            title="Remove"
          >
            <svg className="w-4 h-4 text-white/60" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
};
