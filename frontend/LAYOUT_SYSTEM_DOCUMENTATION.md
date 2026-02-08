# Dashboard Layout & Navigation System

## Overview

Complete dashboard layout system with responsive sidebar, top navigation, command palette, breadcrumbs, and tab management.

## Components

### 1. **MainLayout** (`src/components/layout/MainLayout.tsx`)
Main container that wraps all pages with the layout structure.

**Usage:**
```tsx
import { MainLayout } from './components/layout';

<MainLayout>
  <YourPage />
</MainLayout>
```

### 2. **Sidebar** (`src/components/layout/Sidebar.tsx`)
Collapsible sidebar with navigation links.

**Features:**
- Collapsible/expandable (desktop)
- Drawer mode (mobile)
- Active route highlighting
- Icon-only mode when collapsed
- Smooth animations

**Navigation Items:**
- Dashboard (`/`)
- Devices (`/devices`)
- Commands (`/commands`)
- Analytics (`/analytics`)
- Settings (`/settings`)

### 3. **TopNav** (`src/components/layout/TopNav.tsx`)
Top navigation bar with search, notifications, and user menu.

**Features:**
- Search bar (opens Command Palette)
- Connection status indicator
- Notification badge
- User profile menu
- Mobile hamburger menu

### 4. **CommandPalette** (`src/components/layout/CommandPalette.tsx`)
Keyboard-driven command palette using `cmdk`.

**Features:**
- Opens with `Cmd/Ctrl + K`
- Fuzzy search
- Recent commands
- Categorized actions
- Keyboard navigation

**Categories:**
- Navigation (Go to pages)
- Devices (Device actions)
- Commands (Execute commands)

### 5. **Breadcrumbs** (`src/components/layout/Breadcrumbs.tsx`)
Dynamic breadcrumb navigation.

**Usage:**
```tsx
import { Breadcrumbs } from '../components/layout';

<Breadcrumbs items={[
  { label: 'Dashboard', path: '/' },
  { label: 'Devices', path: '/devices' },
  { label: 'Device Details' } // Current page (no path)
]} />
```

### 6. **TabSystem** (`src/components/layout/TabSystem.tsx`)
Multi-tab interface for managing multiple views.

**Features:**
- Closable tabs
- Active tab highlighting
- Overflow handling (shows "+N more")
- Tab hover effects

**Usage:**
```tsx
import { TabSystem } from '../components/layout';

const tabs = [
  { id: '1', label: 'Device 1', icon: <Smartphone /> },
  { id: '2', label: 'Device 2', icon: <Smartphone /> },
];

<TabSystem
  tabs={tabs}
  activeTab="1"
  onTabChange={(id) => console.log('Tab changed:', id)}
  onTabClose={(id) => console.log('Tab closed:', id)}
/>
```

## State Management

### Layout Store (`src/stores/layoutStore.ts`)
Zustand store managing layout state.

**State:**
```typescript
{
  sidebarCollapsed: boolean,
  commandPaletteOpen: boolean,
  isMobile: boolean,
  activeTabs: Tab[],
  activeTabId: string | null,
  breadcrumbs: BreadcrumbItem[]
}
```

**Actions:**
- `toggleSidebar()` - Toggle sidebar
- `setSidebarCollapsed(collapsed)` - Set sidebar state
- `closeMobileSidebar()` - Close mobile sidebar
- `openCommandPalette()` - Open command palette
- `closeCommandPalette()` - Close command palette
- `toggleCommandPalette()` - Toggle command palette
- `addTab(tab)` - Add new tab
- `removeTab(tabId)` - Remove tab
- `setActiveTab(tabId)` - Set active tab
- `clearTabs()` - Clear all tabs
- `setBreadcrumbs(items)` - Set breadcrumb trail
- `setIsMobile(isMobile)` - Set mobile state

## Keyboard Shortcuts

Global keyboard shortcuts implemented in `src/hooks/useKeyboardShortcuts.ts`:

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + K` | Open command palette |
| `Cmd/Ctrl + B` | Toggle sidebar |
| `Cmd/Ctrl + /` | Show shortcuts help |

## Responsive Breakpoints

Tailwind CSS breakpoints:

| Breakpoint | Min Width | Behavior |
|------------|-----------|----------|
| Mobile | < 768px | Drawer sidebar, bottom nav |
| Tablet | 768px - 1024px | Collapsible sidebar |
| Desktop | > 1024px | Full sidebar |

## Pages

### DashboardPage (`src/pages/DashboardPage.tsx`)
Main dashboard with stats cards and recent activity.

### DevicesPage (`src/pages/DevicesPage.tsx`)
Device list and management.

### CommandsPage (`src/pages/CommandsPage.tsx`)
Command execution interface.

### AnalyticsPage (`src/pages/AnalyticsPage.tsx`)
Analytics and insights dashboard.

### SettingsPage (`src/pages/SettingsPage.tsx`)
Application settings.

## Routing

Implemented with React Router v6 in `src/App.tsx`:

```tsx
<BrowserRouter>
  <MainLayout>
    <Routes>
      <Route path="/" element={<DashboardPage />} />
      <Route path="/devices" element={<DevicesPage />} />
      <Route path="/commands" element={<CommandsPage />} />
      <Route path="/analytics" element={<AnalyticsPage />} />
      <Route path="/settings" element={<SettingsPage />} />
    </Routes>
  </MainLayout>
</BrowserRouter>
```

## Dependencies

New dependencies installed:
- `cmdk` - Command menu component
- `lucide-react` - Icon library

## Testing

### Manual Testing Checklist

1. **Desktop (> 1024px):**
   - [ ] Sidebar expands/collapses with button
   - [ ] Sidebar shows icons + labels when expanded
   - [ ] Sidebar shows icons only when collapsed
   - [ ] Active route highlighted
   - [ ] Command palette opens with Cmd+K
   - [ ] Navigation works correctly

2. **Tablet (768-1024px):**
   - [ ] Sidebar is collapsible
   - [ ] Layout adjusts correctly
   - [ ] Touch interactions work

3. **Mobile (< 768px):**
   - [ ] Sidebar starts collapsed (off-screen)
   - [ ] Hamburger menu opens drawer
   - [ ] Overlay closes drawer when clicked
   - [ ] Command palette accessible
   - [ ] Responsive stats cards

4. **Keyboard Shortcuts:**
   - [ ] Cmd/Ctrl + K opens command palette
   - [ ] Cmd/Ctrl + B toggles sidebar
   - [ ] Command palette navigation with arrows
   - [ ] Enter selects command
   - [ ] ESC closes command palette

5. **Command Palette:**
   - [ ] Opens with keyboard shortcut
   - [ ] Opens from search bar click
   - [ ] Search filters commands
   - [ ] Recent commands shown
   - [ ] Categories displayed correctly
   - [ ] Navigation changes page

## Customization

### Adding New Navigation Items

Edit `src/components/layout/Sidebar.tsx`:

```tsx
const navItems: NavItem[] = [
  // ... existing items
  { 
    name: 'New Page', 
    path: '/new-page', 
    icon: <YourIcon size={20} /> 
  },
];
```

### Adding New Commands

Edit `src/components/layout/CommandPalette.tsx`:

```tsx
const commands: CommandItem[] = useMemo(() => [
  // ... existing commands
  {
    id: 'new-command',
    label: 'Do Something',
    icon: <Icon size={18} />,
    category: 'Commands',
    action: () => {
      // Your action
      closeCommandPalette();
      addRecentCommand('new-command');
    },
    keywords: ['search', 'terms'],
  },
], [navigate, closeCommandPalette]);
```

### Styling

The layout uses Tailwind CSS with custom design tokens:
- Primary color: Cyan (400-600)
- Gray scale: 50-900
- Animations: 200-300ms transitions

## Next Steps

1. Add user authentication flow
2. Implement device detail views with tabs
3. Add real-time WebSocket connection status
4. Implement notification system
5. Add theme switcher (dark mode)
6. Add keyboard shortcuts help modal
7. Implement drag-and-drop tab reordering

## Files Created

```
frontend/src/
├── components/
│   └── layout/
│       ├── Sidebar.tsx
│       ├── TopNav.tsx
│       ├── CommandPalette.tsx
│       ├── Breadcrumbs.tsx
│       ├── TabSystem.tsx
│       ├── MainLayout.tsx
│       └── index.ts
├── pages/
│   ├── DashboardPage.tsx
│   ├── DevicesPage.tsx
│   ├── CommandsPage.tsx
│   ├── AnalyticsPage.tsx
│   └── SettingsPage.tsx
├── stores/
│   └── layoutStore.ts
└── hooks/
    └── useKeyboardShortcuts.ts
```

## Demo

To view the layout system:

```bash
cd frontend
npm run dev
```

Then navigate to `http://localhost:5173`

Try:
- Clicking sidebar links
- Pressing `Cmd/Ctrl + K` for command palette
- Pressing `Cmd/Ctrl + B` to toggle sidebar
- Resizing browser window for responsive behavior
- Opening mobile view (< 768px) for drawer sidebar
