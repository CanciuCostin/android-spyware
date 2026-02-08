# EagleSpy V5 - CSS Architecture

## 🏗️ Architecture Overview

The CSS architecture follows a modular, scalable approach with clear separation of concerns.

## 📁 File Structure

```
app/assets/stylesheets/
├── modern_variables.scss        # Design tokens & CSS variables
├── responsive.scss              # Mobile-first responsive layouts
├── loading_states.scss          # Skeletons, spinners, progress
├── dark_mode.scss               # Theme system
├── ui_polish.scss               # Components (toasts, modals, buttons)
├── dashboard.scss               # Dashboard-specific styles
└── active_admin.scss            # Main entry point & ActiveAdmin overrides
```

## 🎯 Import Order

```scss
// 1. Variables (foundation)
@import "modern_variables";

// 2. Responsive system
@import "responsive";

// 3. Loading states
@import "loading_states";

// 4. Theme system
@import "dark_mode";

// 5. UI components
@import "ui_polish";

// 6. Page-specific styles
@import "dashboard";
```

**Why this order?**
1. Variables must be loaded first (used by everything)
2. Responsive provides base layout utilities
3. Loading states can use responsive mixins
4. Dark mode overrides colors from variables
5. UI polish uses all above
6. Page-specific styles last (highest specificity)

## 🎨 Design Token System

### CSS Variables

All design decisions are centralized in CSS custom properties:

```scss
:root {
  // Colors
  --color-bg-base: #0a0e17;
  --color-text-primary: #e2e8f0;
  
  // Spacing (8px scale)
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  
  // Typography
  --text-base: 14px;
  --weight-semibold: 600;
  
  // Effects
  --radius-md: 12px;
  --shadow-lg: 0 8px 32px rgba(0, 0, 0, 0.3);
  --transition-base: 250ms cubic-bezier(0.4, 0, 0.2, 1);
}
```

### Benefits

1. **Easy theming** - Change one variable, update everywhere
2. **Runtime updates** - No recompilation needed
3. **Browser DevTools** - Inspect and modify live
4. **Consistency** - Single source of truth

### Usage

```scss
.my-component {
  color: var(--color-text-primary);
  padding: var(--space-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-base);
}
```

## 📱 Mobile-First Approach

### Why Mobile-First?

1. **Performance** - Mobile devices load base styles, desktop loads extras
2. **Progressive Enhancement** - Start simple, add complexity
3. **Modern practice** - Most traffic is mobile

### Breakpoint Strategy

```scss
// Base styles (mobile)
.element {
  grid-template-columns: 1fr;
}

// Tablet (min-width: 768px)
@media (min-width: 768px) {
  .element {
    grid-template-columns: repeat(2, 1fr);
  }
}

// Desktop (min-width: 1024px)
@media (min-width: 1024px) {
  .element {
    grid-template-columns: repeat(4, 1fr);
  }
}
```

### Breakpoint Variables

```scss
$breakpoint-sm: 480px;   // Small mobile
$breakpoint-md: 768px;   // Tablet
$breakpoint-lg: 1024px;  // Desktop
$breakpoint-xl: 1440px;  // Large desktop
```

## 🎭 BEM Naming Convention

### Block Element Modifier (loosely)

```scss
// Block
.stat-card { }

// Element (child)
.stat-card .stat-value { }

// Modifier (variant)
.stat-card[data-color="blue"] { }
```

### Component Prefixes

- `.eagle-*` - App-specific components
- `.stat-*` - Statistics components
- `.device-*` - Device-related components
- `.action-*` - Action buttons/grids
- `.empty-*` - Empty state variants
- `.toast-*` - Toast notification parts
- `.modal-*` - Modal dialog parts

## 🧩 Component Patterns

### Glass-morphism Cards

```scss
@mixin glass-card {
  background: var(--color-bg-card);
  backdrop-filter: blur(var(--glass-blur));
  -webkit-backdrop-filter: blur(var(--glass-blur));
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-lg);
}

.device-card {
  @include glass-card;
}
```

### Touch Targets

```scss
@mixin touch-target {
  min-width: 44px;
  min-height: 44px;
}

.action-btn {
  @include touch-target;
}
```

### Focus Rings

```scss
@mixin focus-ring {
  outline: none;
  box-shadow: 0 0 0 3px var(--color-border-focus);
}

button:focus-visible {
  @include focus-ring;
}
```

## 🌈 Color System

### Color Variants

Each accent color has multiple variants:

```scss
// Base color
--color-accent-blue: #3b82f6;

// RGB values (for alpha transparency)
--color-accent-blue-rgb: 59, 130, 246;

// Usage with transparency
background: rgba(var(--color-accent-blue-rgb), 0.15);
```

### Semantic Colors

```scss
--color-success: var(--color-accent-green);
--color-error: var(--color-accent-red);
--color-warning: var(--color-accent-amber);
--color-info: var(--color-accent-blue);
```

### Color Assignment

```scss
.stat-card {
  &[data-color="blue"] {
    --stat-color: var(--color-accent-blue);
    --stat-color-rgb: var(--color-accent-blue-rgb);
  }
}
```

## 🎬 Animation Strategy

### CSS Transitions (Preferred)

```scss
.card {
  transition: transform var(--transition-base);
  
  &:hover {
    transform: translateY(-2px);
  }
}
```

**Why CSS over JavaScript?**
- Hardware accelerated (GPU)
- 60fps performance
- Simpler to maintain
- Less JavaScript overhead

### Keyframe Animations

```scss
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.element {
  animation: fade-in 0.3s ease;
}
```

### Animation Timing

```scss
--transition-fast: 150ms;   // Quick interactions
--transition-base: 250ms;   // Standard transitions
--transition-slow: 400ms;   // Dramatic effects
```

### Easing Functions

```scss
// Standard easing (most common)
cubic-bezier(0.4, 0, 0.2, 1)

// Emphasized easing (entries)
cubic-bezier(0.16, 1, 0.3, 1)

// Linear (progress bars)
linear
```

## 🔄 Theme System

### CSS Variable Override Pattern

```scss
// Base (dark)
:root {
  --color-bg-base: #0a0e17;
  --color-text-primary: #e2e8f0;
}

// Light theme override
[data-theme="light"] {
  --color-bg-base: #ffffff;
  --color-text-primary: #0f172a;
}
```

### Transition During Theme Change

```scss
* {
  transition: background-color var(--transition-base),
              border-color var(--transition-base),
              color var(--transition-base);
}

// Disable during switch
body.theme-transitioning * {
  transition: none !important;
}
```

## 📐 Spacing System

### 8px Grid

```scss
--space-xs: 4px;   // 0.5 unit
--space-sm: 8px;   // 1 unit
--space-md: 16px;  // 2 units
--space-lg: 24px;  // 3 units
--space-xl: 32px;  // 4 units
--space-2xl: 48px; // 6 units
```

### Why 8px?

1. **Mathematical harmony** - Easily divisible
2. **Icon alignment** - Most icons are 16px, 24px, 32px
3. **Responsive scaling** - Clean scale at all sizes
4. **Industry standard** - Material Design, iOS HIG

## 🎯 Specificity Management

### Specificity Pyramid

```
1. Variables (lowest)
2. Base/reset styles
3. Layout utilities
4. Component defaults
5. Component variants
6. State classes
7. Utility/helper classes
8. !important (avoid)
```

### Avoiding Specificity Wars

```scss
// ❌ Bad (too specific)
.dashboard .device-card .device-header h3 {
  color: white;
}

// ✅ Good (lower specificity)
.device-meta h3 {
  color: var(--color-text-primary);
}
```

## 🔧 Utility Classes

### When to Use

- One-off adjustments
- Rapid prototyping
- Responsive overrides

### Examples

```html
<div class="transition-all fade-in stagger-2">
  Content
</div>
```

## 📦 Component Isolation

### Scoping

```scss
// Dashboard-specific overrides
body.admin_dashboard {
  .header#header {
    background: rgba(13, 17, 23, 0.95);
  }
}
```

### Namespace Collision Prevention

```scss
// Use specific selectors
.eagle-stat-card { }   // App-specific
.aa-panel { }          // ActiveAdmin override
```

## 🚀 Performance Optimization

### CSS Performance Tips

1. **Avoid universal selector** (`*`)
2. **Minimize nesting** (max 3 levels)
3. **Use efficient selectors** (class over tag)
4. **Leverage CSS containment** (`contain: layout`)
5. **Use `will-change` sparingly**

### Example

```scss
// ❌ Bad (expensive)
* div > .card span {
  color: red;
}

// ✅ Good (efficient)
.card-text {
  color: var(--color-text-primary);
}
```

### Hardware Acceleration

```scss
// Triggers GPU acceleration
transform: translateZ(0);
will-change: transform;
```

## 🐛 Debugging Tips

### CSS Variable Inspection

```javascript
// Browser console
getComputedStyle(document.documentElement)
  .getPropertyValue('--color-bg-base');
```

### Layout Debugging

```scss
// Temporarily add borders to visualize
* {
  outline: 1px solid red;
}
```

## 📚 Style Guide

### Do's

✅ Use CSS variables for all colors, spacing, typography  
✅ Write mobile-first responsive styles  
✅ Use semantic class names  
✅ Group related properties together  
✅ Add comments for complex logic  
✅ Use mixins for repeated patterns  

### Don'ts

❌ Hardcode colors or spacing values  
❌ Use `!important` unless absolutely necessary  
❌ Create deep nesting (> 3 levels)  
❌ Use inline styles in production  
❌ Duplicate styles across files  
❌ Use overly specific selectors  

## 🔄 Maintenance

### Adding New Components

1. Create component in appropriate file
2. Use existing variables/mixins
3. Follow naming conventions
4. Add responsive styles if needed
5. Document in COMPONENT_LIBRARY.md

### Modifying Existing Components

1. Check for usage across app
2. Test in both themes
3. Test on mobile devices
4. Verify no specificity conflicts
5. Update documentation

### Deprecating Components

1. Mark as deprecated in comments
2. Add migration path
3. Update documentation
4. Remove after transition period

---

## 📖 Further Reading

- [CSS Custom Properties](https://developer.mozilla.org/en-US/docs/Web/CSS/--*)
- [BEM Methodology](http://getbem.com/)
- [Mobile-First CSS](https://responsivedesign.is/strategy/page-layout/mobile-first/)
- [CSS Performance](https://web.dev/css-performance/)

---

**Version**: 1.0.0  
**Last Updated**: 2024
