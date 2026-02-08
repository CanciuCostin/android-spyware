# 🎨 Visual Component Reference

Quick visual reference for all modernized components.

---

## 🎨 Color Palette

```
Dark Mode (Default)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Background Base:    #0a0e17  ████████ (Deep Space)
Background Surface: rgba(15, 20, 35, 0.7) ████████ (Glass Dark)
Background Card:    rgba(20, 27, 45, 0.65) ████████ (Card Dark)
Text Primary:       #e2e8f0  ████████ (Near White)
Text Secondary:     #94a3b8  ████████ (Cool Gray)
Text Muted:         #64748b  ████████ (Slate)

Accent Colors
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Blue:    #3b82f6  ████████ (Bright Blue)
Purple:  #8b5cf6  ████████ (Vivid Purple)
Green:   #22c55e  ████████ (Success Green)
Red:     #ef4444  ████████ (Error Red)
Amber:   #f59e0b  ████████ (Warning Amber)
Cyan:    #06b6d4  ████████ (Info Cyan)
```

---

## 📊 Stat Cards

```
┌─────────────────────────────────┐
│ 📱                             │
│ 42                             │ ← Large value
│ DEVICES                        │ ← Label
└─────────────────────────────────┘
  ↑ Top border (color-coded)
  
Available colors: blue, purple, green, red, amber, cyan
Hover: Lifts up + glow effect
Size: Responsive (120px - 200px wide)
```

---

## 🃏 Device Cards

```
┌─────────────────────────────────────────────────────────┐
│ ┌──┐  Samsung Galaxy S21                  ● Online     │ ← Header
│ │📱│  Android 12 · ID: ABC123                          │
│ └──┘                                                     │
├─────────────────────────────────────────────────────────┤
│ 👁 Surveillance │ 📦 Data │ 🎮 Control │ 🤖 AI │ 📊    │ ← Tabs
├─────────────────────────────────────────────────────────┤
│ LIVE MONITORING                                         │ ← Section
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                   │
│ │📹  │ │📍  │ │⌨️  │ │🔔  │ │📋  │                   │
│ │Cam │ │GPS │ │Key │ │Not │ │Clip│                   │
│ └────┘ └────┘ └────┘ └────┘ └────┘                   │
│                                                         │
│ CAPTURE                                                 │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                   │
│ │📷  │ │🖥️  │ │🎬  │ │🎤  │ │🌙  │                   │
│ │Pic │ │Scr │ │Rec │ │Mic │ │Amb │                   │
│ └────┘ └────┘ └────┘ └────┘ └────┘                   │
└─────────────────────────────────────────────────────────┘

Features:
- Glass-morphism background
- Smooth tab switching
- Color-coded action buttons
- Status indicator with pulse animation
- Hover effects on all interactive elements
```

---

## 🔔 Toast Notifications

```
Position: Fixed top-right (24px from edges)

┌─────────────────────────────────────────┐
│ ■ ✅ Device connected successfully   ✕ │ ← Success (green accent)
└─────────────────────────────────────────┘
  ↑ Border (left, color-coded)

┌─────────────────────────────────────────┐
│ ■ ❌ Command failed to execute       ✕ │ ← Error (red accent)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ■ ⚠️  Processing your request...     ✕ │ ← Warning (amber accent)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ ■ ℹ️  Tip: Use keyboard shortcuts    ✕ │ ← Info (blue accent)
└─────────────────────────────────────────┘

Features:
- Slides in from right
- Auto-dismiss after 5s (with progress bar)
- Stack multiple toasts
- Manual close button
- Glass-morphism background
- Smooth exit animation
```

---

## 🪟 Modals

```
┌───────────────────────── Backdrop (blur) ────────────────────────┐
│                                                                   │
│                ┌────────────────────────────────┐                │
│                │ ⚠️  Delete Device?          ✕ │ ← Header       │
│                ├────────────────────────────────┤                │
│                │                                │                │
│                │ This action cannot be undone.  │ ← Body         │
│                │ All data will be permanently   │                │
│                │ deleted.                       │                │
│                │                                │                │
│                ├────────────────────────────────┤                │
│                │            [Cancel] [Delete]   │ ← Footer       │
│                └────────────────────────────────┘                │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

Features:
- Dark backdrop with blur
- ESC key to close
- Click outside to close
- Scale-in animation
- Focus trap for keyboard navigation
- Danger variant for destructive actions
```

---

## ⏳ Loading States

### Skeleton Screen
```
┌─────────────────────────────┐
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░        │ ← Title (shimmer animation)
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░        │ ← Text line
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░      │ ← Text line
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░        │ ← Text line
└─────────────────────────────┘

Shimmer moves left to right →
```

### Spinner
```
    ◐  Small (16px)
   ◐   Medium (20px)
  ◐    Large (32px)
 ◐     XLarge (48px)
 
Rotates 360° continuously
Color: accent-blue
```

### Progress Bar
```
Determinate:
┌────────────────────────────────────────┐
│ Uploading...                      45%  │
└────────────────────────────────────────┘
███████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
↑ Fill (blue → purple gradient)

Indeterminate:
████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
↑ Animated left to right
```

### Button Loading
```
Before:          During:           After:
┌────────────┐   ┌────────────┐   ┌────────────┐
│ Send       │   │     ◐      │   │ Send       │
└────────────┘   └────────────┘   └────────────┘
  Clickable      Loading (gray)    Clickable
```

---

## 🎯 Buttons

```
Primary (Blue):
┌──────────────┐
│ Primary      │ ← Blue gradient background
└──────────────┘

Secondary (Outlined):
┌──────────────┐
│ Secondary    │ ← Transparent with border
└──────────────┘

Danger (Red):
┌──────────────┐
│ Delete       │ ← Red background
└──────────────┘

Ghost (Transparent):
┌──────────────┐
│ Cancel       │ ← Fully transparent
└──────────────┘

All buttons:
- Hover: Lift up 1-2px
- Active: Scale down 0.98
- Disabled: 50% opacity
- Loading: Show spinner
- Min size: 44x44px (touch target)
```

---

## 🏷️ Badges

```
Success: [ ● Online ]     ← Green
Error:   [ ● Offline ]    ← Red
Warning: [ ● Pending ]    ← Amber
Info:    [ ● Processing ] ← Blue

Small, rounded pills with color-coded dots
```

---

## 📭 Empty States

```
┌─────────────────────────────────────────┐
│                                         │
│             📱 (large icon)             │
│                                         │
│        No Devices Connected             │ ← Title
│                                         │
│   Install the APK on a target device   │ ← Description
│        to begin monitoring.             │
│                                         │
│        ┌─────────────────┐              │
│        │ Download APK    │              │ ← Action
│        └─────────────────┘              │
│                                         │
└─────────────────────────────────────────┘

Variants: empty-no-devices, empty-no-data, 
         empty-no-results, empty-error
```

---

## 🎨 Theme Toggle

```
┌────────┐
│ 🌙 ☀️ │ ← Fixed top-right
└────────┘
  ↑   ↑
  │   └─ Light mode (inactive)
  └───── Dark mode (active, highlighted)

Click to toggle
Saves to localStorage
Smooth color transition
```

---

## 📱 Responsive Breakpoints

```
Mobile (< 768px):
┌─────────────────┐
│ [≡] Command Ctr │ ← Collapsed sidebar
├─────────────────┤
│ ┌────┐ ┌────┐  │ ← 2 columns
│ │ 42 │ │ 15 │  │
│ └────┘ └────┘  │
│ ┌────┐ ┌────┐  │
│ │ 89 │ │ 31 │  │
│ └────┘ └────┘  │
└─────────────────┘

Tablet (768px - 1024px):
┌──────────────────────────────┐
│ │ Command Center             │ ← Sidebar visible
│ │                            │
│ │ ┌────┐ ┌────┐ ┌────┐      │ ← 3 columns
│ │ │ 42 │ │ 15 │ │ 89 │      │
│ │ └────┘ └────┘ └────┘      │
└──────────────────────────────┘

Desktop (> 1024px):
┌────────────────────────────────────────────────┐
│ │ Command Center                               │
│ │                                              │
│ │ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ │ ← 6 columns
│ │ │ 42 │ │ 15 │ │ 89 │ │ 31 │ │ 56 │ │ 23 │ │
│ │ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ │
└────────────────────────────────────────────────┘
```

---

## 🎬 Animations

```
Fade In:
0%: ░░░░░ (opacity: 0)
↓
100%: █████ (opacity: 1)
Duration: 300ms

Slide Up:
0%: ▼ (translateY: +20px)
↓
100%: ▲ (translateY: 0)
Duration: 400ms

Pulse Glow:
0%: ● (scale: 1, glow: 0)
↓
50%: ◉ (scale: 1.05, glow: 4px)
↓
100%: ● (scale: 1, glow: 0)
Duration: 2s infinite

Card Hover:
Normal: ░░░░░
↓ (transform: translateY(-2px))
Hover:  ▓▓▓▓▓ + shadow

All animations: 60fps
Easing: cubic-bezier(0.4, 0, 0.2, 1)
```

---

## 📐 Spacing System (8px Grid)

```
--space-xs:  4px   ■
--space-sm:  8px   ■■
--space-md:  16px  ■■■■
--space-lg:  24px  ■■■■■■
--space-xl:  32px  ■■■■■■■■
--space-2xl: 48px  ■■■■■■■■■■■■
```

---

## 🔤 Typography Scale

```
--text-xs:   11px  Small labels
--text-sm:   12px  Secondary text
--text-base: 14px  Body text ← Default
--text-lg:   16px  Large body
--text-xl:   18px  Subheadings
--text-2xl:  22px  Headings
--text-3xl:  28px  Large headings

Font: Poppins (Google Fonts)
Weights: 400 (normal), 500 (medium), 600 (semibold), 700 (bold)
```

---

## 📊 Grid Layouts

```
Stats Grid:
Mobile:  [■■] [■■]           (2 columns)
Tablet:  [■] [■] [■]         (3 columns)
Desktop: [■][■][■][■][■][■]  (6 columns)

Action Grid:
Mobile:  [■] [■] [■]         (3 columns)
Tablet:  [■][■][■][■]        (4 columns)
Desktop: Auto-fill (120px min)

Gap: 16px (--space-md) on desktop
     8px (--space-sm) on mobile
```

---

## 🎨 Glass-morphism Effect

```
Background: rgba(20, 27, 45, 0.65) ← Semi-transparent
Backdrop:   blur(16px)              ← Frosted glass
Border:     1px solid rgba(255, 255, 255, 0.06)
Shadow:     0 8px 32px rgba(0, 0, 0, 0.3)

Creates depth and modern aesthetic
Works on dark backgrounds
```

---

**All components are fully responsive and theme-aware.**  
**Refer to COMPONENT_LIBRARY.md for code examples.**
