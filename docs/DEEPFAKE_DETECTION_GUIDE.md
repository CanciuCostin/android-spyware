# Deepfake & Spoofing Detection Guide

## Overview

EagleSpy V5 includes a comprehensive deepfake and spoofing detection system that analyzes GPS data, media files, voice recordings, and app integrity to identify manipulation attempts on monitored devices.

## Components

### Server-Side Services

| Service | File | Purpose |
|---------|------|---------|
| `DeepfakeDetectionService` | `app/services/deepfake_detection_service.rb` | Orchestrates all detection analyses |
| `GpsSpoofingDetector` | `app/services/gps_spoofing_detector.rb` | GPS-specific spoofing detection |
| `SecurityAnalysisController` | `app/controllers/api/security_analysis_controller.rb` | REST API endpoints |
| `SecurityEvent` | `app/models/security_event.rb` | Database model for events |
| Security Analysis Admin | `app/admin/security_analysis.rb` | Admin dashboard panel |

### Android Client

| Component | File | Purpose |
|-----------|------|---------|
| `IntegrityChecker` | `android-client/.../utils/IntegrityChecker.kt` | Device-side integrity checks |

## API Endpoints

### GPS Analysis
```
GET /api/devices/:id/security/gps_analysis
```

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `latitude` | float | Current latitude |
| `longitude` | float | Current longitude |
| `accuracy` | float | GPS accuracy in meters |
| `provider` | string | Location provider name |
| `installed_apps` | array | List of installed package names |

**Response:**
```json
{
  "status": "ok",
  "data": {
    "spoofing_detected": false,
    "risk_score": 0,
    "alerts": [],
    "analyzed_at": "2026-02-16T12:00:00Z"
  }
}
```

### Media Analysis
```
GET /api/devices/:id/security/media_analysis
```

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `file_path` | string | Path to media file |
| `file_size` | integer | File size in bytes |
| `mime_type` | string | MIME type |
| `exif_data` | object | EXIF metadata hash |

**Response:**
```json
{
  "status": "ok",
  "data": {
    "suspicious": false,
    "findings": [],
    "severity": "low"
  }
}
```

### Tamper Status
```
GET /api/devices/:id/security/tamper_status
```

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `app_signature` | string | Current app signing hash |
| `is_debuggable` | boolean | Debug mode status |
| `is_rooted` | boolean | Root detection result |
| `installer_package` | string | Package installer name |
| `build_type` | string | Build variant type |

**Response:**
```json
{
  "status": "ok",
  "data": {
    "tampered": false,
    "flags": [],
    "severity": "none"
  }
}
```

## Detection Capabilities

### 1. GPS Spoofing Detection

- **Impossible Travel**: Flags movement exceeding 900 km/h between consecutive location reports
- **Mock Location Provider**: Detects when the Android mock location setting is active
- **GPS Accuracy Analysis**: Identifies suspiciously precise readings (<1m) or very poor accuracy (>500m)
- **Spoofing App Detection**: Scans installed apps against a known list of GPS spoofing applications

### 2. Media Manipulation Detection

- **EXIF Analysis**: Checks for editing software signatures (Photoshop, GIMP, FakeApp, etc.)
- **Compression Artifacts**: Flags over-compressed JPEGs that may indicate re-processing
- **Metadata Consistency**: Detects GPS coordinates without camera identification data
- **Thumbnail Integrity**: Checks for stripped or inconsistent thumbnail data

### 3. Voice Deepfake Indicators

- **Sample Rate Analysis**: Flags audio with sample rates below natural speech minimums
- **Frequency Distribution**: Detects missing high-frequency content typical of synthetic speech
- **Silence Ratio**: Identifies abnormally high silence ratios indicating spliced audio

### 4. Anti-Tamper Detection

- **App Signature Verification**: Compares runtime signing certificate against expected hash
- **Debug Detection**: Identifies debugger attachment, TracerPid, and debug build variants
- **Sideload Detection**: Flags apps not installed from Play Store
- **Build Type Verification**: Detects debug builds running in production

### 5. Android Client Integrity (IntegrityChecker.kt)

- **Signature Verification**: SHA-256 hash comparison of APK signing certificate
- **Debugger Detection**: Checks `Debug.isDebuggerConnected()` and TracerPid
- **Root Detection**: Scans for su binaries, Magisk, and root management apps
- **Mock Location Detection**: Checks system settings, mock providers, and spoofing apps
- **Emulator Detection**: Build property analysis, QEMU file checks, goldfish driver detection

## Risk Scoring

GPS spoofing uses a weighted risk score (0-100):

| Severity | Weight |
|----------|--------|
| Critical | 40 |
| High | 25 |
| Medium | 15 |
| Low | 5 |

A score above **50** triggers a spoofing detection alert.

## Admin Dashboard

The Security Analysis dashboard (`/admin/security_analysis`) provides:

- **Threat Overview**: Real-time counts of critical/high/medium/low events in the last 24 hours
- **Recent Events Table**: Chronological list of all security events with severity indicators
- **GPS Spoofing Alerts**: Filtered view of GPS-related detections
- **Media Integrity Reports**: Filtered view of media analysis findings
- **Per-Device Status**: Security health status for each monitored device

## Database Schema

```sql
CREATE TABLE security_events (
  id BIGINT PRIMARY KEY,
  device_id VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,
  severity VARCHAR NOT NULL DEFAULT 'info',
  details TEXT,
  detected_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Indexes
CREATE INDEX index_security_events_on_device_id ON security_events(device_id);
CREATE INDEX index_security_events_on_event_type ON security_events(event_type);
CREATE INDEX index_security_events_on_severity ON security_events(severity);
CREATE INDEX index_security_events_on_detected_at ON security_events(detected_at);
CREATE INDEX index_security_events_on_device_and_type ON security_events(device_id, event_type);
CREATE INDEX index_security_events_on_severity_and_time ON security_events(severity, detected_at);
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EXPECTED_APP_SIGNATURE` | (none) | Expected APK signing certificate SHA-256 hash |
| `DEVICE_AUTH_TOKEN` | (none) | Authentication token for API access |

### Tuning Thresholds

Thresholds are defined as constants in the service classes:

- `GpsSpoofingDetector::MAX_SPEED_KMH` — Maximum plausible speed (default: 900)
- `GpsSpoofingDetector::SUSPICIOUS_ACCURACY_THRESHOLD` — Minimum GPS accuracy in meters (default: 1.0)
- `DeepfakeDetectionService::KNOWN_SPOOF_APPS` — List of known GPS spoofing package names
