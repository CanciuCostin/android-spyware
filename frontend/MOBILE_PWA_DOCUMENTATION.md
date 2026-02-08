# Mobile Responsive Design & PWA Implementation

## Overview

This document describes the mobile-first responsive design and Progressive Web App (PWA) features implemented in EagleSpy V5.

## Mobile Components

### 1. Bottom Navigation (`BottomNavigation.tsx`)

Fixed bottom navigation bar for mobile devices with icons and labels.

**Features:**
- 4 navigation items: Home, Devices, Analytics, Settings
- Active state highlighting
- Haptic feedback on tap (vibration)
- Hidden on desktop (md breakpoint and above)
- Safe area inset support for notched devices

**Usage:**
```tsx
import { BottomNavigation } from '@components/mobile';

function MobileLayout() {
  return (
    <>
      {/* Your content */}
      <BottomNavigation />
    </>
  );
}
```

### 2. Mobile Header (`MobileHeader.tsx`)

Simplified header for mobile with hamburger menu or back button.

**Features:**
- Dynamic back button or menu button
- Centered title with truncation
- Touch-optimized buttons (44x44px)
- Haptic feedback

**Usage:**
```tsx
import { MobileHeader } from '@components/mobile';

function Page() {
  return (
    <MobileHeader 
      title="Device Details"
      showBack={true}
      onMenuClick={() => setDrawerOpen(true)}
    />
  );
}
```

### 3. Swipeable Drawer (`SwipeableDrawer.tsx`)

Side drawer that can be swiped left to close.

**Features:**
- Swipe-to-close gesture
- Backdrop with blur
- Body scroll lock when open
- Smooth animations
- Touch-optimized

**Usage:**
```tsx
import { SwipeableDrawer } from '@components/mobile';

function App() {
  const [open, setOpen] = useState(false);
  
  return (
    <SwipeableDrawer
      isOpen={open}
      onClose={() => setOpen(false)}
      title="Menu"
    >
      {/* Drawer content */}
    </SwipeableDrawer>
  );
}
```

### 4. Swipeable Card (`SwipeableCard.tsx`)

Card component with swipe-to-reveal actions.

**Features:**
- Swipe left to delete (red background)
- Swipe right to archive (blue background)
- Configurable thresholds
- Haptic feedback on action trigger
- Smooth animations

**Usage:**
```tsx
import { SwipeableCard } from '@components/mobile';

function DeviceList() {
  return (
    <SwipeableCard
      onDelete={() => handleDelete()}
      onArchive={() => handleArchive()}
      deleteThreshold={100}
      archiveThreshold={100}
    >
      <div>Device Card Content</div>
    </SwipeableCard>
  );
}
```

### 5. Pull-to-Refresh (`PullToRefresh.tsx`)

Pull-down gesture to refresh content.

**Features:**
- Visual feedback (rotating icon)
- Configurable threshold
- Prevents on scroll
- Haptic feedback
- Async refresh support

**Usage:**
```tsx
import { PullToRefresh } from '@components/mobile';

function DeviceList() {
  const handleRefresh = async () => {
    await fetchDevices();
  };
  
  return (
    <PullToRefresh onRefresh={handleRefresh} threshold={80}>
      {/* List content */}
    </PullToRefresh>
  );
}
```

## Custom Hooks

### useSwipe

Detects swipe gestures in all four directions.

**API:**
```typescript
const swipeHandlers = useSwipe({
  onSwipeLeft: () => console.log('Swiped left'),
  onSwipeRight: () => console.log('Swiped right'),
  onSwipeUp: () => console.log('Swiped up'),
  onSwipeDown: () => console.log('Swiped down'),
  threshold: 50, // Minimum distance in pixels
  velocityThreshold: 0.3, // Minimum velocity
});

return <div {...swipeHandlers}>Swipeable content</div>;
```

### useLongPress

Detects long press (press and hold) gestures.

**API:**
```typescript
const longPressHandlers = useLongPress({
  onLongPress: () => console.log('Long pressed!'),
  delay: 500, // Duration in ms
});

return <div {...longPressHandlers}>Press and hold me</div>;
```

## PWA Features

### Service Worker Configuration

Located in `vite.config.ts`:

**Caching Strategies:**
1. **Static Assets**: Cached on install (precache)
2. **Google Fonts**: CacheFirst strategy
3. **API Calls**: NetworkFirst with 10s timeout, 5min cache
4. **Images**: CacheFirst with 1 year expiration

### Offline Support

The app works offline for:
- Previously visited pages
- Cached API responses
- Static assets (JS, CSS, images)

### Install Prompt

The `PWAInstallPrompt` component shows an install banner:
- Detects installability
- Shows "Install" button
- Handles install event
- Dismissible

**Usage:**
```tsx
import { PWAInstallPrompt } from '@components/PWAInstallPrompt';

function App() {
  return (
    <>
      {/* Your app */}
      <PWAInstallPrompt />
    </>
  );
}
```

### Manifest Configuration

Located in `public/manifest.json`:
- App name and description
- Theme colors
- Display mode: standalone
- Orientation: portrait
- Icons: 192x192 and 512x512

## Mobile-Specific CSS Utilities

### Touch Target

Ensures minimum touch target size (44x44px):
```css
.touch-target {
  min-width: 44px;
  min-height: 44px;
}
```

### Safe Area Insets

Handles notched devices (iPhone X and above):
```css
.safe-area-inset-top {
  padding-top: env(safe-area-inset-top);
}
.safe-area-inset-bottom {
  padding-bottom: env(safe-area-inset-bottom);
}
```

### Touch Optimizations

```css
* {
  -webkit-tap-highlight-color: transparent;
}

body {
  overscroll-behavior-y: contain;
  -webkit-overflow-scrolling: touch;
}

/* Disable iOS zoom on input focus */
input, select, textarea {
  font-size: 16px !important;
}
```

## Responsive Breakpoints

Using Tailwind's default breakpoints:
- `sm`: 640px
- `md`: 768px (tablet)
- `lg`: 1024px
- `xl`: 1280px
- `2xl`: 1536px

Mobile-only components use `md:hidden` to hide on tablet and above.

## Testing Checklist

### Mobile Gestures
- [ ] Swipe left/right/up/down
- [ ] Long press
- [ ] Pull-to-refresh
- [ ] Swipeable cards (delete/archive)
- [ ] Drawer swipe to close

### PWA
- [ ] Install prompt appears
- [ ] App installs successfully
- [ ] Works offline after install
- [ ] Service worker updates properly
- [ ] Caching strategies work

### Mobile UI
- [ ] Bottom navigation works
- [ ] Mobile header shows correctly
- [ ] Touch targets are 44x44px minimum
- [ ] Safe area insets on notched devices
- [ ] No text zoom on input focus (iOS)
- [ ] Smooth scrolling
- [ ] No overscroll bounce on body

### Responsive Design
- [ ] Layout adapts to screen size
- [ ] Typography is readable on mobile
- [ ] Buttons are easy to tap
- [ ] Forms work well on mobile
- [ ] Images are optimized
- [ ] Content fits without horizontal scroll

## Performance Optimizations

### Mobile-Specific
1. **Touch Feedback**: Instant visual/haptic feedback
2. **Lazy Loading**: Components load on demand
3. **Image Optimization**: Responsive images
4. **Code Splitting**: Separate mobile chunks

### PWA-Specific
1. **Precaching**: Static assets cached on install
2. **Runtime Caching**: API responses cached
3. **Background Sync**: Queued when offline
4. **Push Notifications**: (Future implementation)

## Browser Support

### PWA Features
- Chrome/Edge: Full support
- Safari: Partial support (no install prompt, limited service worker)
- Firefox: Full support

### Touch Gestures
- All modern mobile browsers
- Works on tablets
- Degrades gracefully on desktop (mouse events)

## Debugging

### Service Worker
```javascript
// Check service worker status
navigator.serviceWorker.getRegistrations().then(registrations => {
  console.log('Registered service workers:', registrations);
});

// Check cache contents
caches.keys().then(names => {
  console.log('Cache names:', names);
});
```

### PWA Install
```javascript
// Check if app is installed
if (window.matchMedia('(display-mode: standalone)').matches) {
  console.log('App is installed');
}
```

### Haptic Feedback
```javascript
// Test vibration API
if (navigator.vibrate) {
  navigator.vibrate(50); // 50ms vibration
}
```

## Future Enhancements

1. **Biometric Authentication**: Fingerprint/Face ID
2. **Push Notifications**: Real-time alerts
3. **Background Sync**: Offline actions queue
4. **Share Target**: Share files to app
5. **Web Share API**: Share from app
6. **Badge API**: Notification badges
7. **Wake Lock**: Keep screen on
8. **Geolocation**: Device tracking
9. **Camera Access**: QR code scanning
10. **Bluetooth**: Device pairing

## Known Issues

1. Safari doesn't show install prompt (use "Add to Home Screen" manually)
2. iOS doesn't support vibration API in web apps
3. Service worker updates require page refresh in some browsers
4. Pull-to-refresh conflicts with browser's native pull-to-refresh (handled with `overscroll-behavior`)

## Resources

- [Web.dev PWA Guide](https://web.dev/progressive-web-apps/)
- [MDN Touch Events](https://developer.mozilla.org/en-US/docs/Web/API/Touch_events)
- [MDN Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Workbox Documentation](https://developers.google.com/web/tools/workbox)
