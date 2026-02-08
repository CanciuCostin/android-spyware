# Advanced UI Components Integration Guide

Quick start guide for integrating advanced components into EagleSpy V5.

## Quick Links

- **Demo**: `/advanced-demo` route
- **Documentation**: `ADVANCED_COMPONENTS.md`
- **Source**: `src/components/advanced/`
- **Store**: `src/stores/advancedStore.ts`

## Installation

Already installed! Dependencies added:
- ✅ `react-grid-layout` - Widget grid system
- ✅ `react-resizable-panels` - Panel resizing
- ✅ `@types/react-grid-layout` - TypeScript types

## Available Components

1. **SplitScreen** - Compare 2 devices side-by-side
2. **PiPPanel** - Floating, draggable panels
3. **WidgetGrid** - Drag & drop dashboard
4. **ResizablePanels** - Multi-panel layouts
5. **ContextMenu** - Right-click menus
6. **KeyboardShortcutsPanel** - Shortcut reference

## Integration Points

### 1. Device Comparison

**File**: `src/pages/Devices.tsx` (or similar)

```typescript
import { SplitScreen } from '@/components/advanced';
import { useAdvancedStore } from '@/stores';

function DevicesPage() {
  const { splitScreen, setSplitScreen } = useAdvancedStore();

  return (
    <>
      <button onClick={() => setSplitScreen({ enabled: true })}>
        Compare Devices
      </button>

      {splitScreen.enabled && (
        <SplitScreen
          {...splitScreen}
          renderPane={(deviceId) => <DeviceView id={deviceId} />}
          onClose={() => setSplitScreen({ enabled: false })}
        />
      )}
    </>
  );
}
```

### 2. Live Camera PiP

**File**: `src/components/device/CameraView.tsx` (or similar)

```typescript
import { PiPPanel } from '@/components/advanced';
import { useState } from 'react';

function CameraView({ deviceId }) {
  const [showPiP, setShowPiP] = useState(false);

  return (
    <>
      <button onClick={() => setShowPiP(true)}>
        Open in PiP
      </button>

      {showPiP && (
        <PiPPanel
          title={`Camera - ${deviceId}`}
          defaultPosition={{ x: window.innerWidth - 420, y: 20 }}
          defaultSize={{ width: 400, height: 300 }}
          onClose={() => setShowPiP(false)}
        >
          <LiveCameraFeed deviceId={deviceId} />
        </PiPPanel>
      )}
    </>
  );
}
```

### 3. Dashboard Widgets

**File**: `src/pages/Dashboard.tsx`

```typescript
import { WidgetGrid, Widget } from '@/components/advanced';

const widgets: Widget[] = [
  {
    id: 'device-status',
    title: 'Device Status',
    component: <DeviceStatusWidget />,
    defaultSize: { w: 4, h: 2 },
  },
  {
    id: 'activity',
    title: 'Recent Activity',
    component: <ActivityWidget />,
    defaultSize: { w: 8, h: 3 },
  },
  // Add more widgets...
];

function Dashboard() {
  return (
    <div>
      <h1>Dashboard</h1>
      <WidgetGrid widgets={widgets} editable={true} />
    </div>
  );
}
```

### 4. Context Menus

**File**: `src/components/DeviceCard.tsx`

```typescript
import { ContextMenu, MenuItem } from '@/components/advanced';
import { Eye, Edit, Terminal, Trash } from 'lucide-react';

function DeviceCard({ device }) {
  const menuItems: MenuItem[] = [
    {
      id: 'view',
      label: 'View Details',
      icon: <Eye size={14} />,
      onClick: () => navigate(`/devices/${device.id}`),
    },
    {
      id: 'edit',
      label: 'Edit',
      icon: <Edit size={14} />,
      onClick: () => openEditModal(device.id),
    },
    { id: 'divider', label: '', divider: true },
    {
      id: 'terminal',
      label: 'Open Terminal',
      icon: <Terminal size={14} />,
      onClick: () => openTerminal(device.id),
    },
    { id: 'divider2', label: '', divider: true },
    {
      id: 'delete',
      label: 'Delete',
      icon: <Trash size={14} />,
      onClick: () => deleteDevice(device.id),
    },
  ];

  return (
    <ContextMenu items={menuItems} trigger={
      <div className="device-card">
        {/* Device card content */}
      </div>
    } />
  );
}
```

### 5. Global Keyboard Shortcuts

**File**: `src/App.tsx`

```typescript
import { useEffect } from 'react';
import { KeyboardShortcutsPanel, defaultShortcuts } from '@/components/advanced';
import { useAdvancedStore } from '@/stores';

function App() {
  const { shortcutsPanelOpen, toggleShortcutsPanel } = useAdvancedStore();

  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      // Show keyboard shortcuts
      if (e.key === '?' && !e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        toggleShortcutsPanel();
      }

      // Toggle split screen
      if (e.metaKey && e.key === 's') {
        e.preventDefault();
        toggleSplitScreen();
      }

      // Add more shortcuts...
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, []);

  return (
    <>
      {/* Your app content */}
      
      <KeyboardShortcutsPanel
        isOpen={shortcutsPanelOpen}
        onClose={toggleShortcutsPanel}
        shortcuts={defaultShortcuts}
        mode="modal"
      />
    </>
  );
}
```

## Router Setup

Add the demo route to your router:

```typescript
// src/routes.tsx or wherever routes are defined
import { AdvancedDemo } from './pages/AdvancedDemo';

const routes = [
  // ... existing routes
  {
    path: '/advanced-demo',
    element: <AdvancedDemo />,
  },
];
```

## Testing the Demo

1. Start the dev server:
   ```bash
   cd frontend
   npm run dev
   ```

2. Navigate to: `http://localhost:5173/advanced-demo`

3. Try each component:
   - Split Screen: Drag divider, swap devices
   - PiP: Drag, resize, minimize, maximize
   - Widget Grid: Drag widgets, resize, add/remove
   - Resizable Panels: Drag dividers, collapse panels
   - Context Menu: Right-click the element

## Customization

### Custom Widgets

Create your own widgets:

```typescript
const myWidget: Widget = {
  id: 'my-custom-widget',
  title: 'My Custom Widget',
  component: <MyCustomComponent />,
  defaultSize: { w: 4, h: 3 },
  minSize: { w: 2, h: 2 },
};
```

### Custom Shortcuts

Add your own shortcuts:

```typescript
const customShortcuts: KeyboardShortcut[] = [
  ...defaultShortcuts,
  {
    category: 'Custom',
    key: 'Cmd+Shift+X',
    description: 'My custom action',
    action: () => myCustomAction(),
  },
];
```

### Custom Themes

Components use Tailwind classes. Override in your CSS:

```css
/* Override widget grid colors */
.react-grid-item {
  background: your-color;
}

/* Override PiP panel colors */
.fixed.bg-gray-900 {
  background: your-color;
}
```

## Performance Tips

1. **Lazy load components** that aren't immediately visible
2. **Limit PiP panels** to 2-3 active at a time
3. **Use React.memo** for heavy widget components
4. **Debounce layout changes** (built-in for widgets)
5. **Virtualize long lists** in panels

## Troubleshooting

### Widget Grid not rendering
- Check that `react-grid-layout` CSS is imported
- Verify container has explicit height
- Check browser console for errors

### PiP panel not draggable
- Ensure position is not `fixed` on parent
- Check z-index conflicts
- Verify mouse events aren't blocked

### Context menu not showing
- Check that trigger element renders
- Verify menu items array is not empty
- Check z-index (should be 10000+)

### TypeScript errors
- Run `npm run type-check` to see all errors
- Ensure all props match interfaces
- Check import paths are correct

## Next Steps

1. ✅ Review the full documentation: `ADVANCED_COMPONENTS.md`
2. ✅ Try the interactive demo: `/advanced-demo`
3. ✅ Integrate components into your pages
4. ✅ Customize for your needs
5. ✅ Test on different devices/browsers

## Support

- **Issues**: Report bugs or request features
- **Documentation**: `ADVANCED_COMPONENTS.md` (detailed API docs)
- **Code**: `src/components/advanced/` (source code)
- **Store**: `src/stores/advancedStore.ts` (state management)

---

Built with ❤️ for EagleSpy V5
