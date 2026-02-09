import React from 'react';
import { useNotificationStore } from '../../stores/notificationStore';

export const NotificationSettings: React.FC = () => {
  const settings = useNotificationStore((state) => state.settings);
  const updateSettings = useNotificationStore((state) => state.updateSettings);
  const toggleSound = useNotificationStore((state) => state.toggleSound);
  const toggleDoNotDisturb = useNotificationStore((state) => state.toggleDoNotDisturb);
  const toggleBrowserPush = useNotificationStore((state) => state.toggleBrowserPush);
  const setVolume = useNotificationStore((state) => state.setVolume);

  const requestNotificationPermission = async () => {
    if ('Notification' in window && Notification.permission === 'default') {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        updateSettings({ browserPushEnabled: true });
      }
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-xl font-semibold text-white mb-4">Notification Settings</h3>
        <p className="text-white/60 text-sm mb-6">
          Configure how and when you receive notifications
        </p>
      </div>

      {/* Enable Notifications */}
      <div className="p-4 glass-dark rounded-lg border border-white/20">
        <div className="flex items-center justify-between">
          <div>
            <h4 className="text-white font-medium">Enable Notifications</h4>
            <p className="text-white/60 text-sm mt-1">
              Turn all notifications on or off
            </p>
          </div>
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={settings.enabled}
              onChange={(e) => updateSettings({ enabled: e.target.checked })}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-white/20 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-electric-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-electric-500"></div>
          </label>
        </div>
      </div>

      {/* Do Not Disturb */}
      <div className="p-4 glass-dark rounded-lg border border-white/20">
        <div className="flex items-center justify-between">
          <div>
            <h4 className="text-white font-medium">Do Not Disturb</h4>
            <p className="text-white/60 text-sm mt-1">
              Mute all notification sounds and alerts
            </p>
          </div>
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={settings.doNotDisturb}
              onChange={toggleDoNotDisturb}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-white/20 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-electric-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-yellow-500"></div>
          </label>
        </div>
      </div>

      {/* Sound Effects */}
      <div className="p-4 glass-dark rounded-lg border border-white/20">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h4 className="text-white font-medium">Sound Effects</h4>
            <p className="text-white/60 text-sm mt-1">
              Play sounds for notifications
            </p>
          </div>
          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={settings.soundEnabled}
              onChange={toggleSound}
              disabled={settings.doNotDisturb}
              className="sr-only peer"
            />
            <div className="w-11 h-6 bg-white/20 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-electric-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-electric-500 peer-disabled:opacity-50"></div>
          </label>
        </div>

        {/* Volume Control */}
        {settings.soundEnabled && !settings.doNotDisturb && (
          <div className="mt-4">
            <label className="text-white/80 text-sm mb-2 block">Volume</label>
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 text-white/60" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.707.707L4.586 13H2a1 1 0 01-1-1V8a1 1 0 011-1h2.586l3.707-3.707a1 1 0 011.09-.217zM12.293 7.293a1 1 0 011.414 0L15 8.586l1.293-1.293a1 1 0 111.414 1.414L16.414 10l1.293 1.293a1 1 0 01-1.414 1.414L15 11.414l-1.293 1.293a1 1 0 01-1.414-1.414L13.586 10l-1.293-1.293a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
              <input
                type="range"
                min="0"
                max="100"
                value={settings.volume * 100}
                onChange={(e) => setVolume(parseInt(e.target.value) / 100)}
                className="flex-1 h-2 bg-white/20 rounded-lg appearance-none cursor-pointer accent-electric-500"
              />
              <span className="text-white/80 text-sm w-12 text-right">
                {Math.round(settings.volume * 100)}%
              </span>
            </div>
          </div>
        )}
      </div>

      {/* Browser Push Notifications */}
      <div className="p-4 glass-dark rounded-lg border border-white/20">
        <div className="flex items-center justify-between">
          <div>
            <h4 className="text-white font-medium">Browser Push Notifications</h4>
            <p className="text-white/60 text-sm mt-1">
              Show notifications even when the tab is not active
            </p>
            {!('Notification' in window) && (
              <p className="text-yellow-500 text-xs mt-2">
                ⚠️ Browser push notifications are not supported in your browser
              </p>
            )}
            {Notification.permission === 'denied' && (
              <p className="text-red-500 text-xs mt-2">
                ⚠️ Notification permissions have been denied
              </p>
            )}
          </div>
          <div className="flex flex-col items-end gap-2">
            {Notification.permission === 'default' && (
              <button
                onClick={requestNotificationPermission}
                className="px-3 py-1 text-sm bg-electric-500 hover:bg-electric-600 text-dark rounded transition-colors"
              >
                Request Permission
              </button>
            )}
            {Notification.permission === 'granted' && (
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={settings.browserPushEnabled}
                  onChange={toggleBrowserPush}
                  disabled={settings.doNotDisturb}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-white/20 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-electric-500 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-electric-500 peer-disabled:opacity-50"></div>
              </label>
            )}
          </div>
        </div>
      </div>

      {/* Auto-Dismiss Timings */}
      <div className="p-4 glass-dark rounded-lg border border-white/20">
        <h4 className="text-white font-medium mb-4">Auto-Dismiss Timings</h4>
        <p className="text-white/60 text-sm mb-4">
          Configure how long each type of notification stays visible (in seconds)
        </p>

        <div className="space-y-3">
          {Object.entries(settings.autoDismissTiming).map(([type, duration]) => (
            <div key={type} className="flex items-center justify-between">
              <label className="text-white/80 text-sm capitalize">{type}</label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min="0"
                  max="30"
                  step="1"
                  value={duration / 1000}
                  onChange={(e) => {
                    const newDuration = parseInt(e.target.value) * 1000;
                    updateSettings({
                      autoDismissTiming: {
                        ...settings.autoDismissTiming,
                        [type]: newDuration,
                      },
                    });
                  }}
                  className="w-16 px-2 py-1 bg-dark/50 border border-white/20 rounded text-white text-sm text-center"
                />
                <span className="text-white/60 text-sm w-8">s</span>
              </div>
            </div>
          ))}
        </div>

        <p className="text-white/40 text-xs mt-3">
          💡 Set to 0 to never auto-dismiss
        </p>
      </div>
    </div>
  );
};
