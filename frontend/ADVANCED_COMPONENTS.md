# Advanced UI Components Documentation

This document provides comprehensive information about the advanced UI components in EagleSpy V5.

## Table of Contents

- [Overview](#overview)
- [Components](#components)
  - [Split Screen](#split-screen)
  - [Picture-in-Picture Panel](#picture-in-picture-panel)
  - [Widget Grid](#widget-grid)
  - [Resizable Panels](#resizable-panels)
  - [Context Menu](#context-menu)
  - [Keyboard Shortcuts Panel](#keyboard-shortcuts-panel)
- [State Management](#state-management)
- [Integration Guide](#integration-guide)
- [Performance Notes](#performance-notes)
- [Browser Compatibility](#browser-compatibility)

---

## Overview

The Advanced UI Components provide a professional "Mission Control" experience for EagleSpy V5. These components enable:

- **Multi-device comparison** with split screen views
- **Floating panels** for always-on-top monitoring
- **Customizable dashboards** with drag-and-drop widgets
- **Flexible layouts** with resizable panel groups
- **Context-aware menus** with keyboard navigation
- **Keyboard shortcuts** for power users

All components are built with:
- **TypeScript** for type safety
- **React hooks** for state management
- **Zustand** for global state persistence
- **Tailwind CSS** for styling
- **Accessibility** in mind (keyboard navigation, ARIA labels)

---

## Components

### Split Screen

**Purpose**: Compare two devices side-by-side with synchronized views.

**File**: `src/components/advanced/SplitScreen.tsx`

**Props**:
```typescript
interface SplitScreenProps {
  orientation?: 'horizontal' | 'vertical';  // Split direction
  defaultSizes?: [number, number];          // Initial sizes in % [50, 50]
  device1Id?: string;                       // Left/top device
  device2Id?: string;                       // Right/bottom device
  syncScroll?: boolean;                     // Sync scrolling
  onDevice1Change?: (deviceId: string) => void;
  onDevice2Change?: (deviceId: string) => void;
  onClose?: () => void;
  renderPane: (deviceId: string | undefined, paneIndex: number) => React.ReactNode;
}
```

**Features**:
- ✅ Vertical or horizontal split
- ✅ Draggable divider with constraints (10%-90%)
- ✅ Synchronized scrolling option
- ✅ Swap devices with one click
- ✅ Maximize individual panes
- ✅ Smooth resize with visual feedback

**Usage Example**:
```typescript
import { SplitScreen } from '@/components/advanced';

function DeviceComparison() {
  return (
    <SplitScreen
      orientation="vertical"
      defaultSizes={[50, 50]}
      device1Id="device-abc"
      device2Id="device-xyz"
      syncScroll={true}
      renderPane={(deviceId, paneIndex) => (
        <DeviceDetailView deviceId={deviceId} />
      )}
      onClose={() => setShowSplit(false)}
    />
  );
}
```

**Keyboard Shortcuts**:
- `Cmd+S` - Toggle split screen
- `Escape` - Close split screen

---

### Picture-in-Picture Panel

**Purpose**: Floating, always-on-top panel for monitoring (camera feeds, terminals, etc.).

**File**: `src/components/advanced/PiPPanel.tsx`

**Props**:
```typescript
interface PiPPanelProps {
  title: string;                                    // Panel title
  defaultPosition?: { x: number; y: number };      // Initial position
  defaultSize?: { width: number; height: number }; // Initial size
  minSize?: { width: number; height: number };     // Minimum size
  onClose?: () => void;
  children: React.ReactNode;                        // Content
}
```

**Features**:
- ✅ Draggable to any screen position
- ✅ Resizable from 8 handles (corners + edges)
- ✅ Minimize to title bar only
- ✅ Maximize to full screen
- ✅ Snap to screen edges
- ✅ High z-index (always on top)
- ✅ Save/restore state

**Usage Example**:
```typescript
import { PiPPanel } from '@/components/advanced';

function LiveCameraMonitor() {
  return (
    <PiPPanel
      title="Live Camera - Device #1234"
      defaultPosition={{ x: window.innerWidth - 420, y: 20 }}
      defaultSize={{ width: 400, height: 300 }}
      minSize={{ width: 200, height: 150 }}
      onClose={() => closePiP()}
    >
      <CameraFeed deviceId="1234" />
    </PiPPanel>
  );
}
```

**Keyboard Shortcuts**:
- `Cmd+P` - Open PiP panel
- `Escape` - Close PiP panel
- `Space` - Toggle minimize

---

### Widget Grid

**Purpose**: Drag-and-drop dashboard with resizable widgets.

**File**: `src/components/advanced/WidgetGrid.tsx`

**Dependencies**: `react-grid-layout`

**Props**:
```typescript
interface WidgetGridProps {
  widgets: Widget[];                     // Available widgets
  layout?: Layout[];                     // Initial layout
  onLayoutChange?: (layout: Layout[]) => void;
  editable?: boolean;                    // Enable drag/resize
  cols?: number;                         // Grid columns (default: 12)
  rowHeight?: number;                    // Row height in px (default: 80)
}

interface Widget {
  id: string;
  title: string;
  component: React.ReactNode;
  defaultSize?: { w: number; h: number };
  minSize?: { w: number; h: number };
}
```

**Features**:
- ✅ 12-column grid system
- ✅ Drag widgets to reorder
- ✅ Resize widgets from corners
- ✅ Add/remove widgets dynamically
- ✅ Preset layouts (Compact, Detailed, Monitoring)
- ✅ Persist layout to localStorage
- ✅ Widget catalog dropdown

**Usage Example**:
```typescript
import { WidgetGrid, Widget } from '@/components/advanced';

const widgets: Widget[] = [
  {
    id: 'device-status',
    title: 'Device Status',
    component: <DeviceStatusWidget />,
    defaultSize: { w: 4, h: 2 },
    minSize: { w: 2, h: 2 },
  },
  {
    id: 'activity-feed',
    title: 'Activity Feed',
    component: <ActivityFeedWidget />,
    defaultSize: { w: 8, h: 4 },
  },
];

function CustomDashboard() {
  return (
    <WidgetGrid
      widgets={widgets}
      editable={true}
      cols={12}
      rowHeight={80}
      onLayoutChange={(layout) => saveLayout(layout)}
    />
  );
}
```

**Preset Layouts**:
- **Compact**: 3 widgets across, 2 rows high
- **Detailed**: 2 widgets across, 4 rows high
- **Monitoring**: Mixed sizes optimized for real-time data

---

### Resizable Panels

**Purpose**: Multi-panel layout with draggable dividers and collapsible sections.

**File**: `src/components/advanced/ResizablePanels.tsx`

**Dependencies**: `react-resizable-panels`

**Props**:
```typescript
interface ResizablePanelsProps {
  direction?: 'horizontal' | 'vertical';
  panels: PanelConfig[];
  storageKey?: string;  // localStorage key for persistence
}

interface PanelConfig {
  id: string;
  title: string;
  content: React.ReactNode;
  defaultSize?: number;   // % of total space
  minSize?: number;       // Minimum % size
  maxSize?: number;       // Maximum % size
  collapsible?: boolean;  // Can collapse to 0
}
```

**Features**:
- ✅ Horizontal or vertical panels
- ✅ Drag dividers to resize
- ✅ Collapse/expand panels
- ✅ Min/max size constraints
- ✅ Persist sizes to localStorage
- ✅ Visual resize handles
- ✅ Smooth animations

**Usage Example**:
```typescript
import { ResizablePanels, PanelConfig } from '@/components/advanced';

const panels: PanelConfig[] = [
  {
    id: 'sidebar',
    title: 'Device List',
    content: <DeviceList />,
    defaultSize: 25,
    minSize: 15,
    collapsible: true,
  },
  {
    id: 'main',
    title: 'Device Details',
    content: <DeviceDetails />,
    defaultSize: 50,
    minSize: 30,
  },
  {
    id: 'inspector',
    title: 'Inspector',
    content: <Inspector />,
    defaultSize: 25,
    minSize: 15,
    collapsible: true,
  },
];

function DeviceManagement() {
  return (
    <ResizablePanels
      direction="horizontal"
      panels={panels}
      storageKey="device-management-layout"
    />
  );
}
```

---

### Context Menu

**Purpose**: Right-click context menu with nested submenus and keyboard navigation.

**File**: `src/components/advanced/ContextMenu.tsx`

**Props**:
```typescript
interface ContextMenuProps {
  items: MenuItem[];
  trigger: React.ReactNode;  // Element to right-click
}

interface MenuItem {
  id: string;
  label: string;
  icon?: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  divider?: boolean;        // Horizontal separator
  submenu?: MenuItem[];     // Nested menu
}
```

**Features**:
- ✅ Trigger on right-click
- ✅ Position near cursor (with screen edge detection)
- ✅ Nested submenus (unlimited depth)
- ✅ Icons for menu items
- ✅ Keyboard navigation (arrow keys, Enter, Escape)
- ✅ Close on click outside
- ✅ Dividers for grouping

**Usage Example**:
```typescript
import { ContextMenu, MenuItem } from '@/components/advanced';
import { Eye, Edit, Trash, Settings } from 'lucide-react';

const menuItems: MenuItem[] = [
  {
    id: 'view',
    label: 'View Details',
    icon: <Eye size={14} />,
    onClick: () => viewDevice(),
  },
  {
    id: 'edit',
    label: 'Edit',
    icon: <Edit size={14} />,
    onClick: () => editDevice(),
  },
  { id: 'divider1', label: '', divider: true },
  {
    id: 'advanced',
    label: 'Advanced',
    icon: <Settings size={14} />,
    submenu: [
      { id: 'logs', label: 'View Logs', onClick: () => viewLogs() },
      { id: 'terminal', label: 'Open Terminal', onClick: () => openTerminal() },
    ],
  },
  { id: 'divider2', label: '', divider: true },
  {
    id: 'delete',
    label: 'Delete',
    icon: <Trash size={14} />,
    onClick: () => deleteDevice(),
  },
];

function DeviceCard({ device }) {
  return (
    <ContextMenu items={menuItems} trigger={
      <div className="device-card">
        {/* Device content */}
      </div>
    } />
  );
}
```

**Keyboard Navigation**:
- `↑/↓` - Navigate items
- `Enter` - Select item / Open submenu
- `→` - Open submenu
- `←` - Close submenu
- `Escape` - Close menu

---

### Keyboard Shortcuts Panel

**Purpose**: Searchable, categorized list of all keyboard shortcuts.

**File**: `src/components/advanced/KeyboardShortcutsPanel.tsx`

**Props**:
```typescript
interface KeyboardShortcutsPanelProps {
  isOpen: boolean;
  onClose: () => void;
  shortcuts: KeyboardShortcut[];
  mode?: 'modal' | 'panel';  // Display as modal or side panel
}

interface KeyboardShortcut {
  category: string;
  key: string;          // e.g., "Cmd+K", "Ctrl+Shift+P"
  description: string;
  action?: () => void;
}
```

**Features**:
- ✅ Modal or side panel mode
- ✅ Search shortcuts (by key or description)
- ✅ Grouped by category
- ✅ Visual key indicators (⌘, ⌃, ⌥, ⇧)
- ✅ Keyboard navigation
- ✅ Print-friendly view

**Usage Example**:
```typescript
import { KeyboardShortcutsPanel, defaultShortcuts } from '@/components/advanced';

function App() {
  const [showShortcuts, setShowShortcuts] = useState(false);

  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      if (e.key === '?' && !e.metaKey && !e.ctrlKey) {
        setShowShortcuts(true);
      }
    };
    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, []);

  return (
    <>
      {/* Your app */}
      <KeyboardShortcutsPanel
        isOpen={showShortcuts}
        onClose={() => setShowShortcuts(false)}
        shortcuts={defaultShortcuts}
        mode="modal"
      />
    </>
  );
}
```

**Default Shortcuts** (included):
- Navigation: `Cmd+K`, `Cmd+D`, `Cmd+H`, `Cmd+M`
- Devices: `Cmd+F`, `Cmd+R`, `Cmd+S`, `Cmd+P`
- Actions: `Cmd+Enter`, `Cmd+N`, `Cmd+T`, `Cmd+L`
- View: `Cmd+B`, `Cmd+Plus`, `Cmd+Minus`, `Cmd+0`
- General: `Escape`, `?`, `Cmd+,`

---

## State Management

### Advanced Store

**File**: `src/stores/advancedStore.ts`

The `useAdvancedStore` manages state for all advanced components using Zustand with persistence.

**API**:

```typescript
// Split Screen
const { splitScreen, setSplitScreen, toggleSplitScreen, swapSplitDevices } = useAdvancedStore();

// PiP Panels
const { pipPanels, addPiPPanel, removePiPPanel, updatePiPPanel, clearPiPPanels } = useAdvancedStore();

// Widget Layouts
const { saveWidgetLayout, loadWidgetLayout } = useAdvancedStore();

// Panel Sizes
const { savePanelSizes, loadPanelSizes } = useAdvancedStore();

// Keyboard Shortcuts
const { shortcutsPanelOpen, toggleShortcutsPanel } = useAdvancedStore();

// Context Menu
const { contextMenuOpen, openContextMenu, closeContextMenu } = useAdvancedStore();

// Reset
const { resetAdvancedSettings } = useAdvancedStore();
```

**Example Usage**:

```typescript
import { useAdvancedStore } from '@/stores';

function MyComponent() {
  const { addPiPPanel, removePiPPanel } = useAdvancedStore();

  const openCamera = () => {
    const panelId = addPiPPanel({
      title: 'Camera Feed',
      position: { x: 100, y: 100 },
      size: { width: 400, height: 300 },
      isMinimized: false,
      isMaximized: false,
      contentType: 'camera',
      deviceId: 'device-123',
    });
    
    return panelId;
  };

  const closeCamera = (panelId: string) => {
    removePiPPanel(panelId);
  };

  // ...
}
```

**Persistence**:
- Split screen config
- Widget layouts
- Panel sizes
- PiP panel positions (session-only)

**Storage Key**: `eaglespy-advanced-store`

---

## Integration Guide

### Step 1: Import Components

```typescript
import {
  SplitScreen,
  PiPPanel,
  WidgetGrid,
  ResizablePanels,
  ContextMenu,
  KeyboardShortcutsPanel,
} from '@/components/advanced';
```

### Step 2: Import Store

```typescript
import { useAdvancedStore } from '@/stores';
```

### Step 3: Add to Your App

**Device Comparison**:
```typescript
function DeviceView() {
  const { splitScreen, toggleSplitScreen } = useAdvancedStore();

  return (
    <>
      <button onClick={toggleSplitScreen}>
        {splitScreen.enabled ? 'Close' : 'Split View'}
      </button>

      {splitScreen.enabled && (
        <SplitScreen
          {...splitScreen}
          renderPane={(deviceId) => <DeviceContent id={deviceId} />}
          onClose={toggleSplitScreen}
        />
      )}
    </>
  );
}
```

**Live Camera PiP**:
```typescript
function CameraControls({ deviceId }) {
  const { addPiPPanel } = useAdvancedStore();

  const openPiP = () => {
    addPiPPanel({
      title: `Camera - ${deviceId}`,
      position: { x: window.innerWidth - 420, y: 20 },
      size: { width: 400, height: 300 },
      isMinimized: false,
      isMaximized: false,
      contentType: 'camera',
      deviceId,
    });
  };

  return <button onClick={openPiP}>Open PiP</button>;
}
```

**Dashboard with Widgets**:
```typescript
function Dashboard() {
  const widgets = [
    { id: 'status', title: 'Status', component: <StatusWidget /> },
    { id: 'activity', title: 'Activity', component: <ActivityWidget /> },
  ];

  return (
    <WidgetGrid
      widgets={widgets}
      editable={true}
      cols={12}
      rowHeight={80}
    />
  );
}
```

**Context Menus on Device Cards**:
```typescript
function DeviceCard({ device }) {
  const menuItems = [
    { id: 'view', label: 'View', onClick: () => viewDevice(device.id) },
    { id: 'edit', label: 'Edit', onClick: () => editDevice(device.id) },
  ];

  return (
    <ContextMenu items={menuItems} trigger={
      <div className="device-card">{device.name}</div>
    } />
  );
}
```

### Step 4: Add Global Keyboard Shortcuts

```typescript
function App() {
  const { toggleShortcutsPanel } = useAdvancedStore();

  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      // Show shortcuts panel
      if (e.key === '?' && !e.metaKey && !e.ctrlKey) {
        toggleShortcutsPanel();
      }

      // Your other shortcuts...
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, []);

  return (
    <>
      {/* Your app */}
      <KeyboardShortcutsPanel
        isOpen={shortcutsPanelOpen}
        onClose={toggleShortcutsPanel}
        shortcuts={defaultShortcuts}
      />
    </>
  );
}
```

---

## Performance Notes

### Optimization Tips

1. **Split Screen**:
   - Use `React.memo` for pane content
   - Disable sync scroll if not needed
   - Virtualize long lists in panes

2. **PiP Panels**:
   - Limit number of active panels (max 3-4)
   - Pause heavy content when minimized
   - Use lazy loading for panel content

3. **Widget Grid**:
   - Use `shouldComponentUpdate` in widgets
   - Lazy load widget components
   - Debounce layout changes (300ms)
   - Limit max widgets (recommended: 12)

4. **Resizable Panels**:
   - Use `React.memo` for panel content
   - Throttle resize handlers (16ms)
   - Avoid heavy renders during resize

5. **Context Menu**:
   - Use virtual scrolling for long menus (>50 items)
   - Lazy render submenus
   - Debounce keyboard navigation (100ms)

### Memory Management

```typescript
// Clean up PiP panels on unmount
useEffect(() => {
  return () => {
    clearPiPPanels();
  };
}, []);

// Reset widget layouts periodically
useEffect(() => {
  const interval = setInterval(() => {
    const layouts = Object.keys(widgetLayouts);
    if (layouts.length > 10) {
      // Keep only last 10
      // ... cleanup logic
    }
  }, 60000); // Every minute

  return () => clearInterval(interval);
}, []);
```

### Monitoring

Use React DevTools Profiler to measure:
- Render times for each component
- Number of re-renders
- Memory usage over time

**Target metrics**:
- Split Screen: < 16ms resize lag
- PiP Panel: < 5ms drag lag
- Widget Grid: < 100ms layout change
- Context Menu: < 50ms open time

---

## Browser Compatibility

### Supported Browsers

| Browser | Version | Notes |
|---------|---------|-------|
| Chrome | ≥ 90 | Full support |
| Firefox | ≥ 88 | Full support |
| Safari | ≥ 14 | Full support |
| Edge | ≥ 90 | Full support |
| Opera | ≥ 76 | Full support |

### Required Features

- CSS Grid Layout
- Flexbox
- CSS Custom Properties (variables)
- ES6+ JavaScript
- Pointer Events API
- Local Storage

### Known Issues

1. **Safari < 14**: Drag handles may flicker
   - **Fix**: Use `-webkit-transform` for handles

2. **Firefox < 88**: PiP resize may lag
   - **Fix**: Disable transitions during resize

3. **Mobile Browsers**: Touch events limited
   - **Recommendation**: Use desktop for advanced components

### Polyfills

None required for target browsers. If supporting older browsers:

```bash
npm install core-js regenerator-runtime
```

Add to app entry:
```typescript
import 'core-js/stable';
import 'regenerator-runtime/runtime';
```

---

## Demo

Visit the interactive demo at `/advanced-demo` to see all components in action.

**Demo includes**:
- Live component previews
- Usage examples
- Code snippets
- Interactive controls

---

## Support

For issues, questions, or feature requests:
- GitHub Issues: [EagleSpy V5 Issues](https://github.com/your-org/eaglespy-v5/issues)
- Documentation: `frontend/ADVANCED_COMPONENTS.md`
- Code: `frontend/src/components/advanced/`

---

## License

MIT License - see LICENSE.md
