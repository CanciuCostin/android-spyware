# Accessibility & Performance Features

## Overview

This document outlines the accessibility (a11y) and performance optimizations implemented in the EagleSpy frontend application to achieve WCAG 2.1 AA compliance and Lighthouse scores of 90+.

## Table of Contents

1. [Accessibility Features](#accessibility-features)
2. [Performance Optimizations](#performance-optimizations)
3. [Components](#components)
4. [Utilities](#utilities)
5. [Testing](#testing)
6. [Best Practices](#best-practices)

---

## Accessibility Features

### WCAG 2.1 AA Compliance

#### Keyboard Navigation
- **Focus Visible**: All interactive elements have visible focus indicators (2px blue outline)
- **Tab Order**: Logical tab order throughout the application
- **Skip Link**: "Skip to main content" link at the top of every page
- **Keyboard Shortcuts**: 
  - `Cmd+K` / `Ctrl+K`: Open command palette
  - `Esc`: Close modals and dialogs
  - `Tab`: Navigate forward
  - `Shift+Tab`: Navigate backward
  - `Enter`: Activate buttons, links, and selected items
  - `Space`: Activate buttons and toggle controls
  - `Arrow Keys`: Navigate within command palette, menus, and lists
  - `/` (future): Quick search focus

#### Screen Reader Support
- **Semantic HTML**: Proper heading hierarchy (h1, h2, h3, etc.)
- **ARIA Labels**: All interactive elements have appropriate ARIA labels
- **ARIA Live Regions**: Notifications use `role="alert"` for screen reader announcements
- **Alt Text**: All images have descriptive alt text
- **Form Labels**: All form inputs have associated labels

#### Visual Accessibility
- **Color Contrast**: All text meets WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text)
- **Focus Indicators**: 2px solid outline with 2px offset on focus-visible
- **High Contrast Mode**: Support for Windows High Contrast mode with enhanced borders
- **Reduced Motion**: Respects `prefers-reduced-motion` user preference

#### Component Accessibility
All components include:
- Proper ARIA attributes (role, aria-label, aria-describedby, etc.)
- Keyboard event handlers
- Focus management
- Screen reader text where needed

**Recent Enhancements (v1.1.0)**:
- Toast notifications now announce automatically with `role="alert"`
- Modals trap focus and return focus on close
- All form inputs have proper label associations
- Loading states are announced to screen readers
- Activity feeds support keyboard navigation
- Command palette has enhanced ARIA support
- Decorative icons hidden from screen readers with `aria-hidden="true"`

---

## Performance Optimizations

### Core Web Vitals Tracking

The application monitors and reports Core Web Vitals:
- **LCP** (Largest Contentful Paint): < 2.5s
- **FID** (First Input Delay): < 100ms
- **CLS** (Cumulative Layout Shift): < 0.1
- **FCP** (First Contentful Paint): < 1.8s
- **TTFB** (Time to First Byte): < 800ms

### Code Splitting

```typescript
// Automatic route-based code splitting
const Dashboard = lazy(() => import('./pages/Dashboard'));
const DevicesPage = lazy(() => import('./pages/DevicesPage'));
```

### Bundle Optimization

- **Manual Chunks**: Vendor libraries split into separate chunks
  - `react-vendor`: React, React DOM, React Router
  - `ui-vendor`: UI libraries (Lucide React, CMDK)
- **Tree Shaking**: Unused code automatically removed
- **Compression**: Gzip and Brotli compression enabled
- **Source Maps**: Disabled in production builds

### Asset Optimization

- **Lazy Loading**: Images and heavy components load on demand
- **Preconnect**: DNS prefetch for API endpoints
- **Font Display**: `font-display: swap` for custom fonts

### Caching Strategy

```typescript
// Service worker cache strategy (if implemented)
{
  static: 'cache-first',
  api: 'network-first',
  images: 'cache-first'
}
```

---

## Components

### Accessibility Components

#### VisuallyHidden

Hides content visually but keeps it accessible to screen readers.

```tsx
import { VisuallyHidden } from '@/components/a11y';

<VisuallyHidden>
  Additional context for screen readers
</VisuallyHidden>
```

#### SkipLink

Allows keyboard users to skip navigation and jump to main content.

```tsx
import { SkipLink } from '@/components/a11y';

<SkipLink href="#main-content" label="Skip to main content" />
```

#### FocusTrap

Traps focus within a modal or dialog for better keyboard navigation.

```tsx
import { FocusTrap } from '@/components/a11y';

<FocusTrap active={isOpen} onEscape={onClose}>
  <Modal>{/* Modal content */}</Modal>
</FocusTrap>
```

### Performance Components

#### LazyLoad

Lazy loads components when they enter the viewport.

```tsx
import { LazyLoad } from '@/components/performance';

<LazyLoad threshold={0.1} rootMargin="50px">
  <HeavyComponent />
</LazyLoad>
```

#### ErrorBoundary

Catches React errors and displays fallback UI.

```tsx
import { ErrorBoundary } from '@/components/performance';

<ErrorBoundary fallback={<ErrorFallback />}>
  <App />
</ErrorBoundary>
```

---

## Utilities

### Web Vitals

Track and report Core Web Vitals metrics.

```typescript
import { reportWebVitals } from '@/utils/webVitals';

reportWebVitals({
  enabled: true,
  debug: true,
  onReport: (metric) => {
    console.log(metric);
    // Send to analytics
  },
});
```

---

## Testing

### Automated Accessibility Testing

**Development Mode**:
- Axe-core runs automatically in development
- Reports accessibility violations in console
- Checks color contrast, ARIA usage, and more

**ESLint**:
```bash
npm run lint
```

Includes `eslint-plugin-jsx-a11y` for static analysis.

### Manual Testing

**Keyboard Navigation**:
1. Navigate the entire app using only Tab/Shift+Tab
2. Verify all interactive elements are reachable
3. Test modal focus trapping
4. Verify skip link functionality

**Screen Reader Testing**:
- Test with NVDA (Windows)
- Test with JAWS (Windows)
- Test with VoiceOver (macOS)

**Lighthouse Audit**:
```bash
npm run build
npm run preview
# Open in Chrome DevTools > Lighthouse
```

Target scores:
- Performance: 90+
- Accessibility: 95+
- Best Practices: 95+
- SEO: 90+

---

## Best Practices

### Accessibility

1. **Always use semantic HTML**
   ```tsx
   // Good
   <button onClick={handleClick}>Click me</button>
   
   // Bad
   <div onClick={handleClick}>Click me</div>
   ```

2. **Provide alt text for images**
   ```tsx
   <img src="device.png" alt="Samsung Galaxy S21 device" />
   ```

3. **Use ARIA attributes sparingly**
   - Only when semantic HTML isn't enough
   - Always test with screen readers

4. **Maintain focus management**
   ```tsx
   // Focus first input when modal opens
   useEffect(() => {
     if (isOpen) {
       inputRef.current?.focus();
     }
   }, [isOpen]);
   ```

5. **Test with real users**
   - Include users with disabilities in testing
   - Test with actual assistive technologies

### Performance

1. **Lazy load heavy components**
   ```tsx
   const Chart = lazy(() => import('./Chart'));
   ```

2. **Optimize images**
   - Use WebP format
   - Provide srcset for responsive images
   - Lazy load below-fold images

3. **Minimize bundle size**
   - Use bundle analyzer to identify large dependencies
   - Tree-shake unused code
   - Split large chunks

4. **Monitor Core Web Vitals**
   - Track in production
   - Set up alerts for regressions
   - Optimize based on real user data

5. **Use React best practices**
   - Memoize expensive computations
   - Use React.memo for expensive components
   - Avoid unnecessary re-renders

---

## Resources

### Accessibility
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [MDN Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)

### Performance
- [Web Vitals](https://web.dev/vitals/)
- [Lighthouse Documentation](https://developers.google.com/web/tools/lighthouse)
- [React Performance](https://react.dev/learn/render-and-commit)

### Tools
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [WAVE Browser Extension](https://wave.webaim.org/extension/)
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)

---

## Changelog

### Version 1.1.0 (2024-03 - WCAG 2.1 AA Compliance Update)

#### Accessibility Improvements
- **Toast Component**: Added `role="alert"`, `aria-live="assertive"`, and `aria-atomic="true"` for screen reader announcements
- **Modal Component**: Integrated FocusTrap, added `role="dialog"`, `aria-modal="true"`, and proper focus management
- **Input Component**: 
  - Proper label association with unique IDs (htmlFor/id)
  - Added `aria-invalid` and `aria-describedby` for error states
  - Error messages now have `role="alert"` for immediate announcement
- **Button Component**: Added `aria-busy` and `aria-disabled` states for loading and disabled buttons
- **Spinner Component**: Added `role="status"`, `aria-live="polite"`, and screen reader text
- **ActivityFeed Component**: 
  - Implemented `role="feed"` for activity stream
  - Added keyboard navigation for feed items
  - Proper semantic markup with `<article>` and `<time>` elements
- **CommandPalette Component**: Enhanced with proper ARIA labels and keyboard hints
- **General**: Added `aria-hidden="true"` to decorative icons throughout the application

#### Testing & Documentation
- Created comprehensive A11Y_TESTING_CHECKLIST.md with manual testing procedures
- Updated ACCESSIBILITY_PERFORMANCE.md with latest improvements
- ESLint jsx-a11y rules enforced and remaining issues documented

#### Known Issues
- Some complex form labels need association fixes (in progress)
- Map component keyboard navigation being enhanced
- Chart accessibility improvements planned

### Version 1.0.0 (2024-02)
- Initial implementation of WCAG 2.1 AA compliance
- Core Web Vitals tracking
- Accessibility components (VisuallyHidden, SkipLink, FocusTrap)
- Performance components (LazyLoad, ErrorBoundary)
- Bundle optimization with code splitting
- Automated accessibility testing with axe-core
- ESLint rules for accessibility
