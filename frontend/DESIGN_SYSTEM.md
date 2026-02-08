# Design System & Component Library

## Overview

A comprehensive design system built with **Tailwind CSS**, featuring atomic components, design tokens, and a Next-Gen UI aesthetic with glass-morphism, cyber themes, and neon accents.

## Installation

Tailwind CSS and dependencies are already installed:

```bash
npm install -D tailwindcss postcss autoprefixer
```

## Configuration

### Tailwind Config (`tailwind.config.js`)

The Tailwind configuration includes:
- **Custom Colors**: Electric Blue, Cyber Purple, Neon Green, True Black
- **Glass-morphism utilities**
- **Animation utilities** (glow, slide, fade)
- **Custom shadows** (neon effects)
- **Custom fonts**: Inter (sans), Fira Code (mono)

### Design Tokens (`src/styles/tokens.ts`)

TypeScript constants for consistent theming:
- `colors` - Brand color palette
- `spacing` - Standardized spacing scale
- `typography` - Font families, sizes, weights
- `shadows` - Custom shadow effects
- `borderRadius` - Border radius scale
- `transitions` - Animation timings and easings

### Global Styles (`src/styles/global.css`)

- Tailwind base imports
- Custom glass-morphism classes (`.glass`, `.glass-dark`)
- Gradient utilities (`.gradient-electric`, `.gradient-cyber`, `.gradient-neon`)
- Glow effects (`.glow-electric`, `.glow-cyber`, `.glow-neon`)
- Custom scrollbar styles
- Cyber grid animation

## Atomic Components

### Button

**Location**: `src/components/ui/Button.tsx`

**Variants**: `primary`, `secondary`, `ghost`, `danger`  
**Sizes**: `sm`, `md`, `lg`

```tsx
import { Button } from '@components/ui';

<Button variant="primary" size="md">Click Me</Button>
<Button variant="secondary" isLoading>Loading...</Button>
<Button variant="ghost" icon={<Icon />}>With Icon</Button>
```

### Input

**Location**: `src/components/ui/Input.tsx`

```tsx
import { Input } from '@components/ui';

<Input 
  label="Email" 
  placeholder="Enter email..."
  helperText="We'll never share your email"
  error="Invalid email"
  icon={<SearchIcon />}
/>
```

### Card

**Location**: `src/components/ui/Card.tsx`

**Variants**: `default`, `glass`, `dark`, `gradient`

```tsx
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@components/ui';

<Card variant="glass" hover>
  <CardHeader>
    <CardTitle>Title</CardTitle>
  </CardHeader>
  <CardContent>Content here</CardContent>
  <CardFooter>Footer</CardFooter>
</Card>
```

### Modal

**Location**: `src/components/ui/Modal.tsx`

**Sizes**: `sm`, `md`, `lg`, `xl`

```tsx
import { Modal, ModalFooter } from '@components/ui';

<Modal 
  isOpen={isOpen} 
  onClose={() => setIsOpen(false)}
  title="Modal Title"
  size="md"
>
  <p>Modal content</p>
  <ModalFooter>
    <Button onClick={handleConfirm}>Confirm</Button>
  </ModalFooter>
</Modal>
```

### Badge

**Location**: `src/components/ui/Badge.tsx`

**Variants**: `success`, `warning`, `danger`, `info`, `default`  
**Sizes**: `sm`, `md`, `lg`

```tsx
import { Badge } from '@components/ui';

<Badge variant="success" dot>Online</Badge>
<Badge variant="warning">Idle</Badge>
```

### Avatar

**Location**: `src/components/ui/Avatar.tsx`

**Sizes**: `sm`, `md`, `lg`, `xl`  
**Status**: `online`, `offline`, `away`, `busy`, `idle`

```tsx
import { Avatar } from '@components/ui';

<Avatar 
  src="/avatar.jpg" 
  fallback="JD"
  size="md"
  status="online"
/>
```

### Spinner

**Location**: `src/components/ui/Spinner.tsx`

**Variants**: `electric`, `cyber`, `neon`  
**Sizes**: `sm`, `md`, `lg`, `xl`

```tsx
import { Spinner } from '@components/ui';

<Spinner size="md" variant="electric" />
```

### Toast

**Location**: `src/components/ui/Toast.tsx`

**Types**: `success`, `error`, `warning`, `info`

```tsx
import { Toast, ToastContainer } from '@components/ui';

<ToastContainer toasts={toasts} onClose={removeToast} />
```

## Compound Components

### DeviceCard

**Location**: `src/components/DeviceCard.tsx`

A card component for displaying device information with status indicators.

```tsx
import { DeviceCard } from '@components/DeviceCard';

<DeviceCard
  device={{
    id: '1',
    name: 'Galaxy S21',
    model: 'Samsung Galaxy S21',
    os: 'Android 13',
    status: 'online',
    lastSeen: '2 mins ago',
    batteryLevel: 85,
    location: 'New York, USA',
  }}
  onClick={(device) => console.log(device)}
  onAction={(action, device) => console.log(action, device)}
/>
```

### CommandPanel

**Location**: `src/components/CommandPanel.tsx`

A panel for executing commands with terminal-like output.

```tsx
import { CommandPanel } from '@components/CommandPanel';

<CommandPanel
  deviceId="device-1"
  onExecute={async (cmd) => {
    await executeCommand(cmd);
  }}
  commandHistory={['get_location', 'take_photo']}
/>
```

### StatCard

**Location**: `src/components/StatCard.tsx`

A card for displaying dashboard statistics with icons and change indicators.

**Variants**: `electric`, `cyber`, `neon`, `default`

```tsx
import { StatCard } from '@components/StatCard';

<StatCard
  title="Total Devices"
  value={42}
  change={{ value: 12, type: 'increase' }}
  variant="electric"
  icon={<DeviceIcon />}
/>
```

## Demo Page

View all components in action at `/design-system` route.

**Location**: `src/pages/DesignSystemDemo.tsx`

The demo page showcases:
- All atomic components with various configurations
- Compound components with mock data
- Interactive examples (modals, toasts)
- Responsive layouts

## Design Principles

### Glass-morphism

All components use glass-morphism for a modern, translucent aesthetic:
- Backdrop blur effects
- Semi-transparent backgrounds
- Subtle borders with opacity

### Color Scheme

- **Electric Blue** (#3b82f6) - Primary actions, highlights
- **Cyber Purple** (#8b5cf6) - Secondary actions, accents
- **Neon Green** (#22c55e) - Success states, positive indicators
- **True Black** (#000000) - Backgrounds, depth

### Typography

- **Sans-serif**: Inter - Clean, modern UI text
- **Monospace**: Fira Code - Code, terminal outputs

### Animations

All animations use:
- Duration: 150ms (fast), 300ms (base), 500ms (slow)
- Easing: ease-out for entrances, ease-in for exits
- Hardware-accelerated transforms

## Usage in App

1. Import global styles in `main.tsx`:
```tsx
import './styles/global.css';
```

2. Import components:
```tsx
import { Button, Card, Input } from '@components/ui';
import { DeviceCard, StatCard } from '@components';
```

3. Use design tokens in TypeScript:
```tsx
import { colors, spacing, typography } from '@styles/tokens';

const styles = {
  color: colors.electric[500],
  padding: spacing.md,
  fontFamily: typography.fontFamily.sans,
};
```

## Customization

### Extending Tailwind

Add custom utilities in `tailwind.config.js`:

```js
theme: {
  extend: {
    colors: {
      'my-color': '#hexcode',
    },
  },
}
```

### Adding New Components

1. Create component in `src/components/ui/`
2. Export from `src/components/ui/index.ts`
3. Use consistent prop patterns (variant, size, etc.)
4. Add TypeScript types
5. Include in demo page

## Testing

Run the dev server to test components:

```bash
npm run dev
```

Navigate to `http://localhost:5173/design-system` to view the demo page.

## Build

Build the project with Tailwind CSS:

```bash
npm run build
```

The build process will:
1. Purge unused CSS classes
2. Minify the output
3. Generate optimized production bundle

## Browser Support

- Chrome/Edge: Latest 2 versions
- Firefox: Latest 2 versions
- Safari: Latest 2 versions

## Performance

- Tree-shaking: Only used Tailwind classes are included
- Code splitting: Components lazy-loadable
- Optimized animations: GPU-accelerated transforms
- No external dependencies: Pure Tailwind + React

## Accessibility

All components include:
- Proper ARIA attributes
- Keyboard navigation support
- Focus indicators
- Semantic HTML

## Future Enhancements

- [ ] Storybook integration
- [ ] Component unit tests
- [ ] Dark/light mode toggle
- [ ] More compound components (tables, forms, navigation)
- [ ] Animation presets library
- [ ] Responsive preview tool
