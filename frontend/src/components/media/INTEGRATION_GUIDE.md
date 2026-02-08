# Media Components Integration Guide

## 🚀 5-Minute Quick Start

### Step 1: Install Dependencies
```bash
npm install yet-another-react-lightbox zustand
```

### Step 2: Import Components
```tsx
import {
  PhotoGallery,
  VideoGallery,
  AudioGallery,
  LightboxComponent,
  VideoPlayer,
  AudioPlayer
} from '@/components/media';
```

### Step 3: Use in Your App
```tsx
// In your device details page
<PhotoGallery deviceId={deviceId} />
<VideoGallery deviceId={deviceId} />
<AudioGallery deviceId={deviceId} />
```

---

## 📋 Component Structure

### PhotoGallery → Lightbox
```tsx
<PhotoGallery deviceId="device-123" />
  ├─ Shows masonry grid of photos
  ├─ Click photo → opens Lightbox
  └─ Lightbox provides zoom, rotate, metadata
```

### VideoGallery → Modal → VideoPlayer
```tsx
<VideoGallery deviceId="device-123" />
  ├─ Shows grid of video thumbnails
  ├─ Click thumbnail → opens modal
  └─ Modal contains VideoPlayer
```

### AudioGallery → AudioPlayer (Inline)
```tsx
<AudioGallery deviceId="device-123" />
  ├─ Shows list of audio files
  └─ Each row has inline AudioPlayer (compact)
```

---

## 🔧 API Requirements

Your backend must provide these endpoints:

### GET Endpoints
```
GET /api/devices/{deviceId}/photos?page=1&limit=20&sort=date&order=desc
GET /api/devices/{deviceId}/videos?page=1&limit=12&sort=date&order=desc
GET /api/devices/{deviceId}/audios?page=1&limit=20&sort=date&order=desc
```

### Response Format
```json
{
  "photos": [
    {
      "id": "uuid",
      "type": "photo",
      "url": "https://...",
      "thumbnailUrl": "https://...",
      "filename": "photo.jpg",
      "size": 2048000,
      "width": 1920,
      "height": 1080,
      "capturedAt": "2024-02-07T12:00:00Z",
      "deviceId": "device-123",
      "appSource": "Camera",
      "metadata": { "iso": 400, "exposure": 1 }
    }
  ],
  "hasMore": true
}
```

### POST Endpoints for Bulk Operations
```
POST /api/devices/{deviceId}/photos/bulk-delete
POST /api/devices/{deviceId}/photos/bulk-download

POST /api/devices/{deviceId}/videos/bulk-delete
POST /api/devices/{deviceId}/videos/bulk-download

POST /api/devices/{deviceId}/audios/bulk-delete
POST /api/devices/{deviceId}/audios/bulk-download
```

Request body:
```json
{
  "ids": ["id1", "id2", "id3"]
}
```

---

## 🎨 Customize Theme (Optional)

Add to your global CSS:
```css
:root {
  --primary-color: #2196f3;
  --primary-darker: #1976d2;
  --success-color: #4caf50;
  --success-darker: #45a049;
  --error-color: #f44336;
  --error-darker: #da190b;
  --text-primary: #333333;
  --text-secondary: #666666;
  --surface-elevated: #ffffff;
  --border-color: #e0e0e0;
}
```

---

## 📱 Responsive Behavior

Components automatically adjust for:
- **Desktop** (1400px+): Full layout with all features
- **Tablet** (1000px): Reduced columns, responsive toolbar
- **Mobile** (700px): Single column, simplified controls
- **Small mobile** (<480px): Minimal layout, touch-optimized

No additional configuration needed!

---

## ⌨️ Keyboard Support

All major actions support keyboard shortcuts:

**In Lightbox (Image Viewer):**
- `←` Previous image
- `→` Next image
- `+` Zoom in
- `-` Zoom out
- `R` Rotate
- `I` Toggle info
- `Esc` Close

**In VideoPlayer:**
- `Space` Play/Pause
- `←` Seek -5s
- `→` Seek +5s
- `F` Fullscreen
- `M` Mute

**In AudioPlayer:**
- `Space` Play/Pause
- `←` Seek -5s
- `→` Seek +5s
- `M` Mute

---

## 🔍 Search & Filter Implementation

### PhotoGallery Example
```tsx
// Search is handled by component
// Type in search box to filter by filename

// Sort is handled by component
// Change dropdown to sort by date/size/name

// Order toggle (ascending/descending)
// Click arrow button to toggle order
```

All filtering/sorting triggers API refetch automatically!

---

## 📤 Bulk Operations

### Selection Mode
1. Click "Select" button to enter selection mode
2. Click checkboxes to select items
3. Click "Select All" to select all
4. Use "Download" or "Delete" buttons

### For Photos:
```tsx
// Automatically sends to:
POST /api/devices/{deviceId}/photos/bulk-delete
POST /api/devices/{deviceId}/photos/bulk-download
```

### For Videos:
```tsx
// Automatically sends to:
POST /api/devices/{deviceId}/videos/bulk-delete
POST /api/devices/{deviceId}/videos/bulk-download
```

### For Audio:
```tsx
// Automatically sends to:
POST /api/devices/{deviceId}/audios/bulk-delete
POST /api/devices/{deviceId}/audios/bulk-download
```

---

## 🎯 Common Integration Patterns

### Pattern 1: Tab-Based Gallery
```tsx
function DeviceDetails({ deviceId }) {
  const [activeTab, setActiveTab] = useState('photos');

  return (
    <>
      <Tabs value={activeTab} onChange={setActiveTab}>
        <Tab label="Photos" value="photos" />
        <Tab label="Videos" value="videos" />
        <Tab label="Audio" value="audio" />
      </Tabs>

      {activeTab === 'photos' && <PhotoGallery deviceId={deviceId} />}
      {activeTab === 'videos' && <VideoGallery deviceId={deviceId} />}
      {activeTab === 'audio' && <AudioGallery deviceId={deviceId} />}
    </>
  );
}
```

### Pattern 2: Sidebar Navigation
```tsx
function MediaViewer({ deviceId }) {
  const [view, setView] = useState('gallery');

  return (
    <div style={{ display: 'flex' }}>
      <Sidebar onSelectView={setView} />
      <div style={{ flex: 1 }}>
        {view === 'photos' && <PhotoGallery deviceId={deviceId} />}
        {view === 'videos' && <VideoGallery deviceId={deviceId} />}
        {view === 'audio' && <AudioGallery deviceId={deviceId} />}
      </div>
    </div>
  );
}
```

### Pattern 3: All Galleries in Sequence
```tsx
function CompleteMediaView({ deviceId }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '40px' }}>
      <section>
        <h2>Photos</h2>
        <PhotoGallery deviceId={deviceId} />
      </section>
      <section>
        <h2>Videos</h2>
        <VideoGallery deviceId={deviceId} />
      </section>
      <section>
        <h2>Audio Files</h2>
        <AudioGallery deviceId={deviceId} />
      </section>
    </div>
  );
}
```

---

## 🔌 Standalone Player Usage

### VideoPlayer Standalone
```tsx
import { VideoPlayer } from '@/components/media';

function MyVideoApp() {
  const video = {
    id: '123',
    url: 'https://example.com/video.mp4',
    filename: 'my-video.mp4',
    size: 50000000,
    capturedAt: new Date().toISOString(),
  };

  return (
    <VideoPlayer 
      video={video}
      fullscreen={true}
      onEnded={() => console.log('Video finished')}
    />
  );
}
```

### AudioPlayer Standalone (Full Mode)
```tsx
import { AudioPlayer } from '@/components/media';

function MyAudioApp() {
  const audio = {
    id: '456',
    url: 'https://example.com/audio.mp3',
    filename: 'my-audio.mp3',
    size: 5000000,
    duration: 300,
    capturedAt: new Date().toISOString(),
  };

  return (
    <AudioPlayer 
      audio={audio}
      compact={false}
    />
  );
}
```

### AudioPlayer Standalone (Compact Mode)
```tsx
import { AudioPlayer } from '@/components/media';

function MyAudioList() {
  return (
    <div>
      {audios.map(audio => (
        <div key={audio.id}>
          <h4>{audio.filename}</h4>
          <AudioPlayer audio={audio} compact={true} />
        </div>
      ))}
    </div>
  );
}
```

---

## 🧪 Testing Checklist

### Functionality
- [ ] Photos display in masonry grid
- [ ] Lightbox opens on photo click
- [ ] Zoom and rotate work in lightbox
- [ ] Videos show thumbnails with duration
- [ ] Video modal opens on click
- [ ] Video player controls work
- [ ] Audio list displays correctly
- [ ] Audio players work inline
- [ ] Waveform renders on audio play

### Interactions
- [ ] Search filters items correctly
- [ ] Sort buttons work (date/size/name)
- [ ] Order toggle (asc/desc) works
- [ ] Selection mode enables/disables
- [ ] Multi-select works
- [ ] Select All button works
- [ ] Bulk delete confirms and works
- [ ] Bulk download works
- [ ] Infinite scroll loads more items

### Keyboard
- [ ] Arrow keys navigate lightbox
- [ ] +/- zoom works
- [ ] Space plays/pauses video
- [ ] F toggles fullscreen
- [ ] M toggles mute
- [ ] Esc closes lightbox/modal

### Responsive
- [ ] Desktop layout correct
- [ ] Tablet layout correct
- [ ] Mobile layout correct
- [ ] Touch interactions work
- [ ] Buttons are touch-friendly

### Browser
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Chrome
- [ ] Mobile Safari

---

## 🐛 Troubleshooting

### Lightbox not opening
**Solution**: Verify `useMediaStore` is initialized and `openLightbox` is being called.

### Waveform not showing
**Solution**: Check browser console for Web Audio API errors. Ensure audio CORS is configured.

### Videos not playing
**Solution**: Verify media URLs are accessible. Check CORS headers on media server.

### Buttons not responding
**Solution**: Check for event propagation issues with parent elements.

### Performance issues
**Solution**: Implement pagination limits or reduce items per page.

---

## 📊 Performance Optimization

### Already Implemented
- ✅ Lazy loading images
- ✅ Infinite scroll (not all at once)
- ✅ Canvas rendering only when needed
- ✅ Event debouncing
- ✅ Memory cleanup on unmount

### You Can Enhance By
- Adding pagination limits to API
- Implementing virtual scrolling for large lists
- Caching API responses
- Compressing media assets
- Using CDN for media delivery

---

## 🔐 Security Notes

1. **Media URLs**: Should be signed/authenticated if sensitive
2. **Bulk Operations**: Implement server-side auth checks
3. **Search Input**: Already sanitized by React
4. **File Operations**: Validate on backend

---

## 📞 Support Resources

1. **README.md** - Full implementation guide
2. **QUICK_REFERENCE.md** - Quick lookup
3. **Component source code** - Well-commented
4. **CSS classes** - Semantic and descriptive

---

## ✨ Next Steps

1. ✅ Install dependencies
2. ✅ Import components
3. ✅ Add to your page
4. ✅ Configure API endpoints
5. ✅ Test all features
6. ✅ Deploy!

---

## 🎉 You're Ready!

All components are production-ready. Just integrate and deploy!

**Questions?** Check README.md or QUICK_REFERENCE.md in the media components folder.
