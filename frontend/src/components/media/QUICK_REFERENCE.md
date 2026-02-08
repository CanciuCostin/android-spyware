# Media Components - Quick Reference Guide

## Component Files Created

| File | Size | Type | Purpose |
|------|------|------|---------|
| PhotoGallery.tsx | 8.5 KB | Component | Masonry photo gallery with lightbox |
| PhotoGallery.css | 6.2 KB | Stylesheet | Masonry layout and toolbar styling |
| Lightbox.tsx | 8.5 KB | Component | Full-screen image viewer with zoom & rotate |
| Lightbox.css | 7.5 KB | Stylesheet | Lightbox controls and metadata panel |
| VideoGallery.tsx | 10.3 KB | Component | Video grid with modal player |
| VideoGallery.css | 9.1 KB | Stylesheet | Grid layout and modal styling |
| VideoPlayer.tsx | 10.6 KB | Component | Custom video player with controls |
| VideoPlayer.css | 7.6 KB | Stylesheet | Player controls and fullscreen styling |
| AudioGallery.tsx | 8.9 KB | Component | Audio list with inline players |
| AudioGallery.css | 6.5 KB | Stylesheet | List layout and player styling |
| AudioPlayer.tsx | 11.4 KB | Component | Waveform player with controls |
| AudioPlayer.css | 10.1 KB | Stylesheet | Waveform visualization and controls |
| index.ts | 396 B | Export | Component exports |
| README.md | 8.9 KB | Documentation | Implementation guide |

**Total: 14 files, ~113 KB**

---

## Component Hierarchy

```
PhotoGallery/
├── Gallery toolbar (search, sort, select)
├── Masonry grid
└── Individual photo items
    └── LightboxComponent (on click)

VideoGallery/
├── Gallery toolbar
├── Video grid
└── Individual video cards
    └── Modal with VideoPlayer

AudioGallery/
├── Gallery toolbar
├── Audio list
└── Individual audio items
    └── AudioPlayer (inline, compact mode)

VideoPlayer/
├── Video element
└── Custom controls
    ├── Play/pause
    ├── Progress bar
    ├── Volume
    └── Playback speed

AudioPlayer/
├── Audio element
├── Waveform canvas
└── Custom controls
    ├── Play/pause
    ├── Progress bar
    ├── Volume
    └── Playback speed
```

---

## Key Props & Interfaces

### PhotoGallery
```tsx
interface PhotoGalleryProps {
  deviceId: string;
}
```

### Lightbox
```tsx
interface LightboxProps {
  items: MediaItem[];
  index: number;
  isOpen: boolean;
  onClose: () => void;
  onPrevious?: () => void;
  onNext?: () => void;
}
```

### VideoGallery
```tsx
interface VideoGalleryProps {
  deviceId: string;
}
```

### VideoPlayer
```tsx
interface VideoPlayerProps {
  video: MediaItem;
  autoPlay?: boolean;
  onEnded?: () => void;
  fullscreen?: boolean;
}
```

### AudioGallery
```tsx
interface AudioGalleryProps {
  deviceId: string;
}
```

### AudioPlayer
```tsx
interface AudioPlayerProps {
  audio: MediaItem;
  compact?: boolean;
  onPlayingChange?: (isPlaying: boolean) => void;
}
```

---

## Keyboard Shortcuts

### Lightbox (Image Viewer)
| Key | Action |
|-----|--------|
| ← / → | Previous / Next image |
| + | Zoom in |
| − | Zoom out |
| R | Rotate image |
| I | Toggle info panel |
| Esc | Close |

### VideoPlayer
| Key | Action |
|-----|--------|
| Space | Play / Pause |
| ← / → | Seek ±5s |
| F | Toggle fullscreen |
| M | Mute / Unmute |

### AudioPlayer
| Key | Action |
|-----|--------|
| Space | Play / Pause |
| ← / → | Seek ±5s |
| M | Mute / Unmute |

---

## CSS Variables (Theme Customization)

```css
--primary-color         /* Main action color, default: #2196f3 */
--primary-darker        /* Darker shade of primary */
--success-color         /* Success/download color, default: #4caf50 */
--success-darker        /* Darker shade of success */
--error-color           /* Error/delete color, default: #f44336 */
--error-darker          /* Darker shade of error */
--text-primary          /* Primary text color, default: #333 */
--text-secondary        /* Secondary text color, default: #666 */
--surface-elevated      /* Card/panel background, default: #ffffff */
--border-color          /* Border color, default: #e0e0e0 */
```

---

## Common Use Cases

### Gallery with Lightbox (Photo Viewer)
```tsx
import { PhotoGallery } from '@/components/media';

<PhotoGallery deviceId={deviceId} />
```

### Just the Lightbox Component
```tsx
import { LightboxComponent } from '@/components/media';
import { useMediaStore } from '@/stores/mediaStore';

const { lightboxOpen, lightboxItems, lightboxIndex, closeLightbox } = useMediaStore();

<LightboxComponent
  items={lightboxItems}
  index={lightboxIndex}
  isOpen={lightboxOpen}
  onClose={closeLightbox}
/>
```

### Standalone Video Player
```tsx
import { VideoPlayer } from '@/components/media';

<VideoPlayer 
  video={videoItem} 
  fullscreen={true}
  onEnded={() => console.log('Video ended')}
/>
```

### Standalone Audio Player (Full Mode)
```tsx
import { AudioPlayer } from '@/components/media';

<AudioPlayer 
  audio={audioItem}
  compact={false}
  onPlayingChange={(isPlaying) => console.log(isPlaying)}
/>
```

### Standalone Audio Player (Compact Mode)
```tsx
import { AudioPlayer } from '@/components/media';

<AudioPlayer 
  audio={audioItem}
  compact={true}
/>
```

---

## Responsive Behavior

### Photo & Video Galleries
- **Desktop (1400px+)**: 4 columns (photos), auto-fill columns (videos)
- **Large Tablet (1000px)**: 3 columns (photos), 2 columns (videos)
- **Tablet (700px)**: 2 columns (photos), stacked (videos)
- **Mobile (< 700px)**: 1 column / 2 columns (mobile)

### Audio Gallery
- **Desktop (1024px+)**: Full player inline
- **Tablet (768px - 1023px)**: Reduced player width
- **Mobile (< 768px)**: Stacked layout

### Players
- **Auto-hide controls**: 3 seconds when playing (video)
- **Mobile**: Simplified controls, smaller buttons
- **Fullscreen**: All available space used

---

## Performance Considerations

1. **Image Lazy Loading**: All images use `loading="lazy"`
2. **Infinite Scroll**: Prevents loading all items at once
3. **Waveform Canvas**: Only renders when audio is playing
4. **Control Auto-hide**: Reduces DOM interaction when playing
5. **Request Debouncing**: Sort/filter resets pagination

---

## Browser Support

- Chrome/Edge: Full support
- Firefox: Full support
- Safari: Full support (iOS 15+)
- Mobile browsers: Full support with touch optimizations

---

## Known Limitations

1. **Lightbox**: Requires `yet-another-react-lightbox` library
2. **Audio Waveform**: Uses Web Audio API (not available in some older browsers)
3. **Fullscreen**: May require user gesture in some browsers
4. **Audio Context**: May be blocked by browser autoplay policies

---

## Troubleshooting

### Lightbox not opening
- Ensure `useMediaStore` is properly initialized
- Check that `openLightbox` is being called with correct items

### Waveform not showing
- Check browser console for Web Audio API errors
- Ensure audio CORS is properly configured
- Try a different audio file format (MP3, WAV, OGG)

### Controls not responding
- Ensure event handlers aren't being prevented by parent elements
- Check for z-index conflicts with other elements
- Verify keyboard event listeners are properly attached

### Player stops playing
- Check API responses for media URLs
- Verify CORS headers on media server
- Ensure adequate browser permissions for audio/video

---

## Dependencies Installation

Add to `package.json`:
```json
{
  "dependencies": {
    "yet-another-react-lightbox": "^3.x.x",
    "zustand": "^4.x.x"
  }
}
```

Or install via npm:
```bash
npm install yet-another-react-lightbox zustand
```

---

## Future Enhancements

- [ ] Subtitle support for videos
- [ ] Playlists for audio/video
- [ ] Thumbnail scrubbing on video progress bar
- [ ] Equalizer for audio player
- [ ] Annotation tools for photos
- [ ] Media comparison (before/after)
- [ ] Social sharing options
- [ ] Advanced metadata editor
