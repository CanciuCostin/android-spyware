# Keylog Analytics Guide

## Overview

The Keylog Analytics Dashboard provides aggregated, anonymized typing analytics for devices enrolled in the EagleSpy V5 MDM platform. All data is collected with explicit user consent via the GDPR-compliant consent management system.

**Key Principle:** This module provides *analytics only* — aggregate statistics about typing activity, app usage patterns, and session metrics. It does not perform credential detection or password extraction.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────────────┐     ┌──────────────────┐
│  React Frontend │────▶│  API Controller           │────▶│  Analytics       │
│  KeylogAnalytics│     │  KeylogAnalyticsController│     │  Service         │
│  .tsx           │     │                           │     │                  │
└─────────────────┘     └──────────────────────────┘     └──────────────────┘
                              │                                 │
┌─────────────────┐           │ consent check                   │ queries
│  ActiveAdmin    │           ▼                                 ▼
│  Keylog         │     ┌──────────────┐              ┌──────────────────┐
│  Analytics Page │     │ DeviceConsent │              │ Keylog Model     │
└─────────────────┘     │ (middleware)  │              │ (PostgreSQL)     │
                        └──────────────┘              └──────────────────┘
┌─────────────────┐
│  JS Dashboard   │     ┌──────────────────────────┐
│  keylog_        │────▶│  Export Service           │
│  dashboard.js   │     │  KeylogExportService      │
└─────────────────┘     └──────────────────────────┘
```

---

## API Endpoints

All endpoints require device authentication and an active `data_collection` consent.

### `GET /api/devices/:id/keylog_analytics`

Returns full analytics summary for a device.

**Query Parameters:**
| Param       | Type   | Default      | Description           |
|-------------|--------|--------------|-----------------------|
| start_date  | ISO8601| 30 days ago  | Start of date range   |
| end_date    | ISO8601| now          | End of date range     |

**Response:**
```json
{
  "device_id": "abc123",
  "consent_status": "granted",
  "analytics": {
    "summary": {
      "total_keystrokes": 15420,
      "unique_apps": 12,
      "active_days": 22,
      "avg_keystrokes_per_day": 701.0
    },
    "app_usage": [...],
    "activity_timeline": [...],
    "hourly_heatmap": [...],
    "peak_hours": [...],
    "word_count": { "total_characters": 48000, "estimated_words": 9600 },
    "sessions": { "total_sessions": 85, "avg_session_minutes": 12.3 }
  }
}
```

### `GET /api/devices/:id/keylog_analytics/app_usage`

Per-app keystroke distribution.

### `GET /api/devices/:id/keylog_analytics/activity_timeline`

**Additional Parameters:**
| Param       | Type   | Default  | Description              |
|-------------|--------|----------|--------------------------|
| granularity | string | hourly   | `hourly` or `daily`      |

### `GET /api/devices/:id/keylog_analytics/export`

Export analytics report.

**Additional Parameters:**
| Param         | Type   | Default | Description          |
|---------------|--------|---------|----------------------|
| export_format | string | json    | `csv` or `json`      |

### Error Responses

| Status | Code               | Description                      |
|--------|--------------------|----------------------------------|
| 403    | CONSENT_REQUIRED   | No active data_collection consent|
| 404    | -                  | Device not found                 |

---

## Consent Enforcement

Every analytics endpoint verifies that the device has an active `data_collection` consent via `DeviceConsent`. The consent check:

1. Looks up `DeviceConsent` where `device_id = device.id` and `consent_type = 'data_collection'`
2. Verifies `granted = true` and `revoked_at IS NULL`
3. Returns HTTP 403 with `CONSENT_REQUIRED` if not met

Export reports include the consent verification timestamp.

---

## Frontend Components

### React Component (`frontend/src/components/KeylogAnalytics.tsx`)

```tsx
import { KeylogAnalytics } from './components/KeylogAnalytics';

<KeylogAnalytics deviceId="123" apiBasePath="/api" />
```

**Features:**
- Summary stat cards (keystrokes, apps, days, avg/day)
- Activity timeline bar chart
- App usage donut chart
- Peak hours horizontal bar chart
- Heatmap (hour × day of week)
- Session & word count summary
- Date range picker (7/30/90 days)
- App filter input
- CSV/JSON export buttons
- Consent status badge

### ActiveAdmin Page (`/admin/keylog_analytics`)

Available in the admin sidebar under **📦 Data → 📊 Keylog Analytics**.

### JavaScript Pack (`app/javascript/packs/keylog_dashboard.js`)

Chart.js-based dashboard for the ActiveAdmin page with identical functionality.

---

## Backend Services

### `KeylogAnalyticsService`

```ruby
service = KeylogAnalyticsService.new(device, start_date: 7.days.ago, end_date: Time.current)
result = service.call
# => { summary: {...}, app_usage: [...], activity_timeline: [...], ... }
```

**Methods:** `summary_stats`, `app_usage_distribution`, `activity_timeline`, `hourly_heatmap`, `peak_activity_hours`, `word_count_estimate`, `session_summary`

### `KeylogExportService`

```ruby
csv_data = KeylogExportService.new(device, format: :csv).call
json_data = KeylogExportService.new(device, format: :json).call
```

---

## Files Created

| File | Description |
|------|-------------|
| `app/controllers/api/keylog_analytics_controller.rb` | API controller with consent checks |
| `app/services/keylog_analytics_service.rb` | Analytics computation service |
| `app/services/keylog_export_service.rb` | CSV/JSON export service |
| `app/admin/keylog_analytics.rb` | ActiveAdmin analytics page |
| `app/javascript/packs/keylog_dashboard.js` | Chart.js dashboard for admin |
| `frontend/src/components/KeylogAnalytics.tsx` | React analytics component |
| `docs/KEYLOG_ANALYTICS_GUIDE.md` | This documentation |
