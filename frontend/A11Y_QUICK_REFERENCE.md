# Quick Reference: Accessibility & Performance

**Version 1.1.0** - Updated March 2024

Quick reference for developers working on EagleSpy V5 frontend. For complete details, see [ACCESSIBILITY_PERFORMANCE.md](./ACCESSIBILITY_PERFORMANCE.md) and [A11Y_TESTING_CHECKLIST.md](./A11Y_TESTING_CHECKLIST.md).

---

## 🚀 Quick Start

### Run Development with A11y Checks
```bash
cd frontend
npm run dev
# Axe-core runs automatically, check console for a11y violations
```

### Run Tests
```bash
# Type check
npm run type-check

# Lint (includes a11y rules)
npm run lint

# Build
npm run build

# Preview production build
npm run preview
```

---

## 📚 Common Patterns

### 1. Accessible Button
```tsx
// ✅ Good - Icon button with label
<button
  onClick={handleClick}
  aria-label="Close dialog"
  aria-pressed={isActive}
  aria-busy={isLoading}
>
  <Icon aria-hidden="true" />
</button>

// ❌ Bad - No accessible name
<button onClick={handleClick}>
  <Icon />
</button>
```

### 2. Accessible Form Input
```tsx
// ✅ Good - Proper label association
<div>
  <label htmlFor="email">Email Address</label>
  <input
    id="email"
    type="email"
    aria-required="true"
    aria-invalid={hasError}
    aria-describedby={hasError ? "email-error" : undefined}
  />
  {hasError && (
    <p id="email-error" role="alert">
      Please enter a valid email
    </p>
  )}
</div>

// ❌ Bad - No label association
<div>
  <label>Email</label>
  <input type="email" />
  {hasError && <p>Error</p>}
</div>
```
    <span id="email-error" role="alert">
      Please enter a valid email
    </span>
  )}
</div>
```

### 3. Lazy Load Component
```tsx
import { LazyLoad } from '@/components/performance';

<LazyLoad>
  <Chart data={data} />
</LazyLoad>
```

### 4. Modal with Focus Trap
```tsx
import { FocusTrap } from '@/components/a11y';

<FocusTrap active={isOpen} onEscape={onClose}>
  <div role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <h2 id="modal-title">Modal Title</h2>
    {/* Modal content */}
  </div>
</FocusTrap>
```

### 5. Screen Reader Only Text
```tsx
import { VisuallyHidden } from '@/components/a11y';

<button onClick={handleDelete}>
  <TrashIcon />
  <VisuallyHidden>Delete item</VisuallyHidden>
</button>
```

---

## 🎯 Keyboard Navigation Checklist

- [ ] All interactive elements reachable via Tab
- [ ] Focus indicators visible (blue 2px outline)
- [ ] Logical tab order
- [ ] Skip link works (Tab on page load)
- [ ] Modals trap focus correctly
- [ ] Escape closes modals
- [ ] No keyboard traps

---

## 🔍 Testing Checklist

### Before Commit
- [ ] Run `npm run lint` - no a11y errors
- [ ] Run `npm run type-check` - no type errors
- [ ] Test keyboard navigation
- [ ] Check focus indicators

### Before Deploy
- [ ] Run Lighthouse audit (all scores 90+)
- [ ] Test with screen reader
- [ ] Verify Web Vitals in dev tools
- [ ] Check bundle size (`npm run build`)

---

## 🐛 Common Issues & Fixes

### Issue: Missing focus indicator
```tsx
// ❌ Bad
<div onClick={handleClick}>Click me</div>

// ✅ Good
<button onClick={handleClick}>Click me</button>
```

### Issue: Image without alt text
```tsx
// ❌ Bad
<img src="device.png" />

// ✅ Good
<img src="device.png" alt="Samsung Galaxy S21 device" />

// ✅ Decorative
<img src="icon.png" alt="" role="presentation" />
```

### Issue: Non-semantic HTML
```tsx
// ❌ Bad
<div className="button" onClick={handleClick}>
  Submit
</div>

// ✅ Good
<button onClick={handleClick}>
  Submit
</button>
```

### Issue: Missing form labels
```tsx
// ❌ Bad
<input type="text" placeholder="Enter name" />

// ✅ Good
<label htmlFor="name">Name</label>
<input id="name" type="text" />
```

---

## 📊 Performance Tips

### 1. Lazy Load Routes
```tsx
import { lazy } from 'react';

const Dashboard = lazy(() => import('./pages/Dashboard'));
```

### 2. Memoize Expensive Computations
```tsx
import { useMemo } from 'react';

const processedData = useMemo(() => {
  return expensiveOperation(data);
}, [data]);
```

### 3. Use React.memo for Heavy Components
```tsx
import { memo } from 'react';

export const Chart = memo(({ data }) => {
  // Heavy rendering
});
```

### 4. Optimize Images
```tsx
// Use WebP
<img src="image.webp" alt="Description" />

// Lazy load below-fold
<LazyLoad>
  <img src="image.jpg" alt="Description" />
</LazyLoad>
```

---

## 🔗 Useful Links

### Accessibility
- [WCAG 2.1 Checklist](https://www.a11yproject.com/checklist/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [Axe DevTools](https://www.deque.com/axe/devtools/)

### Performance
- [Web Vitals](https://web.dev/vitals/)
- [Lighthouse Docs](https://developers.google.com/web/tools/lighthouse)
- [React Performance](https://react.dev/learn/render-and-commit)

---

## 📞 Need Help?

1. Check `ACCESSIBILITY_PERFORMANCE.md` for detailed docs
2. Run `npm run lint` to find accessibility issues
3. Check browser console for Axe violations (dev mode)
4. Use Lighthouse in Chrome DevTools

---

**Last Updated**: February 7, 2026
