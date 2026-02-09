# PWA Icons

This directory should contain the following PWA icon files:

## Required Icons

1. **pwa-192x192.png** - 192x192px icon for mobile devices
2. **pwa-512x512.png** - 512x512px icon for splash screens and high-res devices
3. **apple-touch-icon.png** - 180x180px icon for iOS devices
4. **favicon.ico** - 32x32px favicon

## Generating Icons

You can use the following tools to generate PWA icons:

1. **[PWA Asset Generator](https://www.pwabuilder.com/)** - Online tool
2. **[RealFaviconGenerator](https://realfavicongenerator.net/)** - Comprehensive favicon generator
3. **[Favicon.io](https://favicon.io/)** - Simple online generator

## Icon Requirements

- **Format**: PNG (RGB or RGBA)
- **Background**: Solid color (matches theme)
- **Content**: Simple, recognizable logo
- **Padding**: 10% safe zone around edges
- **Maskable**: Icons should work as maskable (for Android adaptive icons)

## Current Status

⚠️ **TODO**: Replace placeholder references with actual icon files.

For now, the app will use the default Vite icon. To add proper icons:

1. Create icons using the dimensions above
2. Save them in the `/public` directory
3. Update the manifest.json if needed
4. Test on different devices

## Testing

After adding icons:
- iOS: Add to home screen and check icon
- Android: Install PWA and check icon
- Desktop: Check browser tab icon and installed app icon
