# Theme System Documentation

## Overview
The EagleSpy V5 Frontend now includes a comprehensive theme system with dark/light modes and customizable color schemes.

## Features

### 1. Theme Modes
- **Light Mode**: Bright colors optimized for daytime use
- **Dark Mode**: Dark colors optimized for nighttime use  
- **Auto Mode**: Automatically follows system theme preference

### 2. Color Schemes
- **Blue** (Electric): Default scheme with blue primary colors
- **Purple** (Cyber): Purple-themed scheme
- **Green** (Neon): Green-themed scheme
- **Red**: Red-themed scheme
- **Custom Accent**: Pick any custom color for accents

### 3. Persistence
- Theme preferences are saved to localStorage
- Automatically restored on page reload
- Survives browser restarts

### 4. Export/Import
- Export theme configuration as JSON
- Import theme configurations from others
- Download theme config files

## Implementation Details

### Files Created

1. **Context**: `src/contexts/ThemeContext.tsx`
   - Manages theme state
   - Handles system theme detection
   - Persists preferences to localStorage
   - Applies CSS variables dynamically

2. **Hook**: `src/hooks/useTheme.ts`
   - Exposes theme context via `useTheme()` hook
   - Easy access from any component

3. **CSS Variables**: `src/styles/themes.css`
   - Defines CSS custom properties for theming
   - Light and dark mode variants
   - Color scheme-specific overrides

4. **Components**:
   - `src/components/ThemeToggle.tsx` - Quick theme switcher button
   - `src/components/settings/ThemeSwitcher.tsx` - Full theme customization panel
   - `src/pages/Settings/ThemeSettings.tsx` - Complete theme settings page

5. **Updated Components**:
   - `Button.tsx` - Uses theme variables
   - `Card.tsx` - Uses theme variables
   - `App.tsx` - Wrapped with ThemeProvider

6. **Configuration**:
   - `tailwind.config.js` - Added theme color utilities
   - `src/styles/global.css` - Imports theme CSS

### Tailwind Classes

The theme system adds new Tailwind utilities:

```tsx
// Background colors
className="theme-bg-base"       // Base background
className="theme-bg-elevated"   // Elevated surfaces
className="theme-bg-card"       // Card backgrounds

// Border colors
className="border-theme-border"

// Text colors
className="theme-text"          // Primary text
className="theme-text-muted"    // Muted text
className="theme-text-subtle"   // Subtle text

// Theme colors
className="theme-primary"       // Primary color text
className="bg-theme-primary"    // Primary color background
className="theme-secondary"     // Secondary color text
className="bg-theme-secondary"  // Secondary color background

// Transitions
className="theme-transition"    // Smooth theme transitions
```

### Usage Example

```tsx
import { useTheme } from '@/hooks';

function MyComponent() {
  const { theme, effectiveTheme, setThemeMode, setColorScheme } = useTheme();

  return (
    <div className="theme-bg-base theme-text">
      <h1>Current theme: {effectiveTheme}</h1>
      <button onClick={() => setThemeMode('dark')}>
        Switch to Dark
      </button>
      <button onClick={() => setColorScheme('purple')}>
        Use Purple Scheme
      </button>
    </div>
  );
}
```

## Available Themes

### Blue (Electric)
- Primary: #3b82f6
- Secondary: #2563eb  
- Accent: #93c5fd

### Purple (Cyber)
- Primary: #a855f7
- Secondary: #9333ea
- Accent: #d8b4fe

### Green (Neon)
- Primary: #22c55e
- Secondary: #16a34a
- Accent: #86efac

### Red
- Primary: #ef4444
- Secondary: #dc2626
- Accent: #fca5a5

## Navigation

- **Quick Toggle**: Theme toggle button in top navigation bar
- **Full Settings**: Navigate to `/settings/theme` for complete customization

## Testing Theme Persistence

1. Select a theme mode and color scheme
2. Refresh the page
3. Theme should be restored automatically
4. Check browser localStorage for `eaglespy-theme` key

## Future Enhancements

Potential improvements:
- More pre-defined color schemes
- Per-component theme overrides
- Theme preview thumbnails
- Accessibility contrast checks
- Theme scheduling (auto-switch at specific times)
