import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardContent, Badge } from '../ui';

interface LogsTabProps {
  deviceId: string;
}

type LogType = 'sms' | 'calls' | 'contacts' | 'apps' | 'browser' | 'clipboard';

interface SMSMessage {
  id: string;
  from: string;
  to: string;
  body: string;
  timestamp: string;
  type: 'received' | 'sent';
}

interface CallLog {
  id: string;
  number: string;
  type: 'incoming' | 'outgoing' | 'missed';
  duration: number;
  timestamp: string;
}

interface Contact {
  id: string;
  name: string;
  phone: string;
  email?: string;
}

interface AppUsage {
  id: string;
  appName: string;
  packageName: string;
  usageTime: number;
  lastUsed: string;
}

interface BrowserHistory {
  id: string;
  url: string;
  title: string;
  timestamp: string;
}

interface ClipboardItem {
  id: string;
  content: string;
  timestamp: string;
}

export const LogsTab: React.FC<LogsTabProps> = ({ deviceId }) => {
  const [activeLog, setActiveLog] = useState<LogType>('sms');

  // Mock data
  const [smsMessages] = useState<SMSMessage[]>([
    {
      id: '1',
      from: '+1234567890',
      to: 'device',
      body: 'Hey, are you free tomorrow?',
      timestamp: new Date(Date.now() - 3600000).toISOString(),
      type: 'received',
    },
    {
      id: '2',
      from: 'device',
      to: '+1234567890',
      body: 'Yes, I am! What time?',
      timestamp: new Date(Date.now() - 3000000).toISOString(),
      type: 'sent',
    },
  ]);

  const [callLogs] = useState<CallLog[]>([
    {
      id: '1',
      number: '+1234567890',
      type: 'incoming',
      duration: 180,
      timestamp: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: '2',
      number: '+0987654321',
      type: 'outgoing',
      duration: 45,
      timestamp: new Date(Date.now() - 10800000).toISOString(),
    },
    {
      id: '3',
      number: '+1122334455',
      type: 'missed',
      duration: 0,
      timestamp: new Date(Date.now() - 14400000).toISOString(),
    },
  ]);

  const [contacts] = useState<Contact[]>([
    { id: '1', name: 'John Doe', phone: '+1234567890', email: 'john@example.com' },
    { id: '2', name: 'Jane Smith', phone: '+0987654321', email: 'jane@example.com' },
    { id: '3', name: 'Bob Johnson', phone: '+1122334455' },
  ]);

  const [appUsage] = useState<AppUsage[]>([
    {
      id: '1',
      appName: 'WhatsApp',
      packageName: 'com.whatsapp',
      usageTime: 3600,
      lastUsed: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: '2',
      appName: 'Chrome',
      packageName: 'com.android.chrome',
      usageTime: 7200,
      lastUsed: new Date(Date.now() - 600000).toISOString(),
    },
  ]);

  const [browserHistory] = useState<BrowserHistory[]>([
    {
      id: '1',
      url: 'https://www.google.com/search?q=weather',
      title: 'Weather - Google Search',
      timestamp: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: '2',
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up - YouTube',
      timestamp: new Date(Date.now() - 3600000).toISOString(),
    },
  ]);

  const [clipboard] = useState<ClipboardItem[]>([
    {
      id: '1',
      content: 'Meeting at 3 PM tomorrow',
      timestamp: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: '2',
      content: 'https://www.example.com/important-link',
      timestamp: new Date(Date.now() - 7200000).toISOString(),
    },
  ]);

  const exportData = (type: LogType) => {
    let data: any[];
    let filename: string;

    switch (type) {
      case 'sms':
        data = smsMessages;
        filename = 'sms-messages';
        break;
      case 'calls':
        data = callLogs;
        filename = 'call-logs';
        break;
      case 'contacts':
        data = contacts;
        filename = 'contacts';
        break;
      case 'apps':
        data = appUsage;
        filename = 'app-usage';
        break;
      case 'browser':
        data = browserHistory;
        filename = 'browser-history';
        break;
      case 'clipboard':
        data = clipboard;
        filename = 'clipboard';
        break;
      default:
        return;
    }

    const json = JSON.stringify(data, null, 2);
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${filename}-${deviceId}-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const logTypes: { id: LogType; label: string; icon: string; count: number }[] = [
    { id: 'sms', label: 'SMS Messages', icon: '💬', count: smsMessages.length },
    { id: 'calls', label: 'Call Logs', icon: '📞', count: callLogs.length },
    { id: 'contacts', label: 'Contacts', icon: '📇', count: contacts.length },
    { id: 'apps', label: 'App Usage', icon: '📱', count: appUsage.length },
    { id: 'browser', label: 'Browser History', icon: '🌐', count: browserHistory.length },
    { id: 'clipboard', label: 'Clipboard', icon: '📋', count: clipboard.length },
  ];

  return (
    <div className="space-y-6">
      {/* Log Type Selector */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        {logTypes.map((type) => (
          <button
            key={type.id}
            onClick={() => setActiveLog(type.id)}
            className={`
              p-4 rounded-lg text-center transition-all
              ${
                activeLog === type.id
                  ? 'bg-electric-500 text-dark-900'
                  : 'bg-white/5 text-white hover:bg-white/10'
              }
            `}
          >
            <div className="text-3xl mb-2">{type.icon}</div>
            <div className="text-sm font-medium">{type.label}</div>
            <div className="text-xs mt-1 opacity-60">{type.count} items</div>
          </button>
        ))}
      </div>

      {/* Log Content */}
      <Card variant="glass">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>{logTypes.find((t) => t.id === activeLog)?.label}</CardTitle>
            <button
              onClick={() => exportData(activeLog)}
              className="px-3 py-1 bg-electric-500 hover:bg-electric-400 text-dark-900 rounded text-sm font-medium transition-colors"
            >
              📥 Export JSON
            </button>
          </div>
        </CardHeader>
        <CardContent>
          {activeLog === 'sms' && <SMSView messages={smsMessages} />}
          {activeLog === 'calls' && <CallLogsView logs={callLogs} />}
          {activeLog === 'contacts' && <ContactsView contacts={contacts} />}
          {activeLog === 'apps' && <AppUsageView apps={appUsage} />}
          {activeLog === 'browser' && <BrowserHistoryView history={browserHistory} />}
          {activeLog === 'clipboard' && <ClipboardView items={clipboard} />}
        </CardContent>
      </Card>
    </div>
  );
};

const SMSView: React.FC<{ messages: SMSMessage[] }> = ({ messages }) => (
  <div className="space-y-2 max-h-[600px] overflow-y-auto">
    {messages.map((msg) => (
      <div key={msg.id} className={`p-4 rounded-lg ${msg.type === 'received' ? 'bg-white/5' : 'bg-electric-500/20'}`}>
        <div className="flex items-start justify-between mb-2">
          <div className="flex items-center gap-2">
            <Badge variant={msg.type === 'received' ? 'default' : 'success'}>
              {msg.type === 'received' ? '📥 Received' : '📤 Sent'}
            </Badge>
            <span className="text-white/60 text-sm">{msg.type === 'received' ? `From: ${msg.from}` : `To: ${msg.to}`}</span>
          </div>
          <span className="text-xs text-white/40">{new Date(msg.timestamp).toLocaleString()}</span>
        </div>
        <div className="text-white">{msg.body}</div>
      </div>
    ))}
  </div>
);

const CallLogsView: React.FC<{ logs: CallLog[] }> = ({ logs }) => {
  const callTypeConfig = {
    incoming: { icon: '📞', label: 'Incoming', variant: 'success' as const },
    outgoing: { icon: '📱', label: 'Outgoing', variant: 'default' as const },
    missed: { icon: '❌', label: 'Missed', variant: 'danger' as const },
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  };

  return (
    <div className="space-y-2 max-h-[600px] overflow-y-auto">
      {logs.map((log) => {
        const config = callTypeConfig[log.type];
        return (
          <div key={log.id} className="p-4 bg-white/5 rounded-lg flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="text-2xl">{config.icon}</span>
              <div>
                <div className="text-white font-medium">{log.number}</div>
                <div className="flex items-center gap-2 mt-1">
                  <Badge variant={config.variant} size="sm">{config.label}</Badge>
                  {log.duration > 0 && (
                    <span className="text-xs text-white/60">{formatDuration(log.duration)}</span>
                  )}
                </div>
              </div>
            </div>
            <span className="text-sm text-white/60">{new Date(log.timestamp).toLocaleString()}</span>
          </div>
        );
      })}
    </div>
  );
};

const ContactsView: React.FC<{ contacts: Contact[] }> = ({ contacts }) => (
  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-h-[600px] overflow-y-auto">
    {contacts.map((contact) => (
      <div key={contact.id} className="p-4 bg-white/5 rounded-lg">
        <div className="flex items-start gap-3">
          <div className="w-12 h-12 bg-electric-500 rounded-full flex items-center justify-center text-dark-900 font-bold text-lg">
            {contact.name[0]}
          </div>
          <div className="flex-1">
            <div className="text-white font-medium">{contact.name}</div>
            <div className="text-sm text-white/60 mt-1">{contact.phone}</div>
            {contact.email && (
              <div className="text-sm text-white/60">{contact.email}</div>
            )}
          </div>
        </div>
      </div>
    ))}
  </div>
);

const AppUsageView: React.FC<{ apps: AppUsage[] }> = ({ apps }) => {
  const formatTime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${mins}m`;
  };

  return (
    <div className="space-y-2 max-h-[600px] overflow-y-auto">
      {apps.map((app) => (
        <div key={app.id} className="p-4 bg-white/5 rounded-lg flex items-center justify-between">
          <div>
            <div className="text-white font-medium">{app.appName}</div>
            <div className="text-xs text-white/40 font-mono mt-1">{app.packageName}</div>
          </div>
          <div className="text-right">
            <div className="text-electric-400 font-bold">{formatTime(app.usageTime)}</div>
            <div className="text-xs text-white/60 mt-1">
              Last: {new Date(app.lastUsed).toLocaleTimeString()}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

const BrowserHistoryView: React.FC<{ history: BrowserHistory[] }> = ({ history }) => (
  <div className="space-y-2 max-h-[600px] overflow-y-auto">
    {history.map((item) => (
      <div key={item.id} className="p-4 bg-white/5 rounded-lg">
        <div className="flex items-start justify-between mb-2">
          <div className="text-white font-medium">{item.title}</div>
          <span className="text-xs text-white/40">{new Date(item.timestamp).toLocaleString()}</span>
        </div>
        <a
          href={item.url}
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-electric-400 hover:text-electric-300 break-all"
        >
          {item.url}
        </a>
      </div>
    ))}
  </div>
);

const ClipboardView: React.FC<{ items: ClipboardItem[] }> = ({ items }) => (
  <div className="space-y-2 max-h-[600px] overflow-y-auto">
    {items.map((item) => (
      <div key={item.id} className="p-4 bg-white/5 rounded-lg">
        <div className="flex items-start justify-between mb-2">
          <span className="text-xs text-white/60">{new Date(item.timestamp).toLocaleString()}</span>
          <button
            onClick={() => navigator.clipboard.writeText(item.content)}
            className="text-xs text-electric-400 hover:text-electric-300"
          >
            📋 Copy
          </button>
        </div>
        <div className="text-white whitespace-pre-wrap">{item.content}</div>
      </div>
    ))}
  </div>
);
