# Screen Mirroring Guide

Enterprise remote screen viewing for IT support and device management.

## Overview

Screen Mirroring provides real-time screen viewing of managed Android devices. This is a standard MDM feature used for remote support, similar to TeamViewer, AnyDesk, or Android Enterprise screen sharing.

**All sessions require explicit `device_monitoring` consent (GDPR Art. 5, 7, 13, 15).**

## Architecture

```
┌──────────────┐     WebSocket/ActionCable     ┌──────────────┐
│  Admin Web   │ ◄──────── frames ──────────── │   Android    │
│  Dashboard   │                               │   Device     │
│  (Canvas)    │ ──── start/stop/settings ───► │  (MediaProj) │
└──────┬───────┘                               └──────┬───────┘
       │                                              │
       │  REST API                                    │
       ▼                                              ▼
┌──────────────┐         ActionCable           ┌──────────────┐
│  Rails API   │ ◄────────────────────────────►│  WebSocket   │
│  Controller  │                               │  Connection  │
└──────────────┘                               └──────────────┘
```

## Consent Requirements

Before screen mirroring can be activated:

1. The device must have `device_monitoring` consent granted via the consent management UI
2. The consent is verified server-side on every `start` request
3. If consent is revoked mid-session, the session is terminated immediately
4. All session events are logged in the audit trail

## Setup

### Server Side

No additional setup required. The screen mirroring service, channel, and controller are included.

Routes are automatically available:

```
POST /api/devices/:id/screen/start   # Start mirroring session
POST /api/devices/:id/screen/stop    # Stop mirroring session
GET  /api/devices/:id/screen/status  # Check session status
```

### Android Client

The `ScreenMirrorService` requires:

1. **MediaProjection permission** — The user is shown Android's native consent dialog
2. **Foreground service notification** — A persistent notification is displayed while mirroring is active (Android requirement)

The service is started via the command system when the admin requests screen mirroring.

## Usage

### Starting a Session

1. Navigate to the device detail page
2. Ensure `device_monitoring` consent is granted (green badge)
3. Click "Start Mirroring"
4. Configure quality (10-100%) and FPS (1-30)
5. The device user will see Android's MediaProjection consent dialog
6. A persistent notification appears on the device: "Your screen is being shared with IT support"

### During a Session

- **Quality slider**: Adjust JPEG quality (lower = less bandwidth)
- **FPS selector**: 1-30 frames per second
- **Screenshot**: Capture current frame as PNG
- **Fullscreen**: Toggle fullscreen viewing mode
- **Timer**: Shows elapsed time and remaining time (max 30 minutes)

### Session Limits

- **Maximum duration**: 30 minutes (auto-stops)
- **One session per device**: Cannot start multiple concurrent sessions
- **Consent required**: Session fails if consent is not granted

## API Reference

### Start Session

```http
POST /api/devices/:id/screen/start
Content-Type: application/json

{
  "fps": 15,
  "quality": 70
}
```

**Response (200):**
```json
{
  "status": "ok",
  "data": {
    "session_id": "uuid",
    "device_id": "abc123",
    "started_by": "admin@example.com",
    "started_at": "2025-01-01T00:00:00Z",
    "status": "active",
    "fps": 15,
    "quality": 70,
    "max_duration_seconds": 1800
  }
}
```

**Error (403) — Consent not granted:**
```json
{
  "status": "error",
  "error_code": "CONSENT_REQUIRED",
  "message": "Device monitoring consent has not been granted."
}
```

### Stop Session

```http
POST /api/devices/:id/screen/stop
```

### Session Status

```http
GET /api/devices/:id/screen/status
```

## WebSocket Channel

Connect to ActionCable and subscribe to `ScreenMirrorChannel`:

```javascript
const subscription = cable.subscriptions.create(
  { channel: 'ScreenMirrorChannel', device_id: deviceId },
  {
    received(data) {
      if (data.type === 'frame') {
        // data.data = base64 JPEG frame
        renderFrame(data.data);
      }
    }
  }
);
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Consent Required" error | Grant `device_monitoring` consent in the consent management UI |
| No frames received | Check device is online and WebSocket connection is active |
| Poor quality | Increase quality slider; reduce FPS to save bandwidth |
| Session auto-stops | Sessions are limited to 30 minutes; start a new one |
| Device notification | This is an Android requirement and cannot be hidden |
