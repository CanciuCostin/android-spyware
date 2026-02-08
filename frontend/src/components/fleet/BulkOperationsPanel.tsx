import React, { useState } from 'react';
import { Button } from '../ui/button';
import { Send, Loader2 } from 'lucide-react';

interface BulkOperationsPanelProps {
  onExecute: (commandType: string, params: any) => Promise<void>;
}

export const BulkOperationsPanel: React.FC<BulkOperationsPanelProps> = ({ onExecute }) => {
  const [commandType, setCommandType] = useState('');
  const [params, setParams] = useState<any>({});
  const [loading, setLoading] = useState(false);

  const commandOptions = [
    { value: 'take_picture', label: 'Take Picture' },
    { value: 'take_screenshot', label: 'Take Screenshot' },
    { value: 'dump_location', label: 'Get Location' },
    { value: 'dump_sysinfo', label: 'System Info' },
    { value: 'dump_device_info', label: 'Device Info' },
    { value: 'toggle_wifi', label: 'Toggle WiFi', params: { enabled: true } },
    { value: 'set_audio_mode', label: 'Set Audio Mode', params: { mode: 'normal' } },
    { value: 'wake_lock', label: 'Wake Lock', params: { enabled: true } },
  ];

  const handleExecute = async () => {
    if (!commandType) return;

    setLoading(true);
    try {
      await onExecute(commandType, params);
    } finally {
      setLoading(false);
    }
  };

  const handleCommandChange = (value: string) => {
    setCommandType(value);
    const selected = commandOptions.find(opt => opt.value === value);
    if (selected?.params) {
      setParams(selected.params);
    } else {
      setParams({});
    }
  };

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-4">
        Bulk Operations
      </h2>
      <p className="text-sm text-gray-600 dark:text-gray-400 mb-6">
        Send commands to all online devices in this group
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Command Type
          </label>
          <select
            value={commandType}
            onChange={(e) => handleCommandChange(e.target.value)}
            className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 text-gray-900 dark:text-white"
          >
            <option value="">Select a command...</option>
            {commandOptions.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>

        {commandType === 'toggle_wifi' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              WiFi State
            </label>
            <select
              value={params.enabled ? 'true' : 'false'}
              onChange={(e) => setParams({ enabled: e.target.value === 'true' })}
              className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 text-gray-900 dark:text-white"
            >
              <option value="true">Enable</option>
              <option value="false">Disable</option>
            </select>
          </div>
        )}

        {commandType === 'set_audio_mode' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Audio Mode
            </label>
            <select
              value={params.mode}
              onChange={(e) => setParams({ mode: e.target.value })}
              className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 text-gray-900 dark:text-white"
            >
              <option value="normal">Normal</option>
              <option value="silent">Silent</option>
              <option value="vibrate">Vibrate</option>
            </select>
          </div>
        )}

        {commandType === 'wake_lock' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Wake Lock State
            </label>
            <select
              value={params.enabled ? 'true' : 'false'}
              onChange={(e) => setParams({ enabled: e.target.value === 'true' })}
              className="w-full px-3 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 text-gray-900 dark:text-white"
            >
              <option value="true">Enable</option>
              <option value="false">Disable</option>
            </select>
          </div>
        )}
      </div>

      <div className="flex items-center gap-4">
        <Button
          onClick={handleExecute}
          disabled={!commandType || loading}
          className="flex items-center gap-2"
        >
          {loading ? (
            <>
              <Loader2 size={20} className="animate-spin" />
              Sending...
            </>
          ) : (
            <>
              <Send size={20} />
              Execute Command
            </>
          )}
        </Button>

        {commandType && (
          <div className="text-sm text-gray-600 dark:text-gray-400">
            Command will be sent to all online devices in this group
          </div>
        )}
      </div>

      {Object.keys(params).length > 0 && (
        <div className="mt-4 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
          <p className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Command Parameters:
          </p>
          <pre className="text-xs text-gray-600 dark:text-gray-400">
            {JSON.stringify(params, null, 2)}
          </pre>
        </div>
      )}
    </div>
  );
};
