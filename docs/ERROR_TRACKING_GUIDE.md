# Error Tracking Guide

## Overview

EagleSpy V5 includes a Sentry-compatible error tracking system that captures, aggregates, and manages application errors. Errors are grouped by fingerprint, tracked for frequency, and can be resolved or ignored through the admin interface or API.

## Architecture

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| Initializer | `config/initializers/error_tracking.rb` | Sentry-compatible config, PII scrubbing, breadcrumbs |
| Model | `app/models/tracked_error.rb` | Database-backed error storage with status management |
| Aggregator | `app/services/error_aggregator.rb` | Groups errors by fingerprint, tracks frequency |
| API Controller | `app/controllers/api/errors_controller.rb` | REST API endpoints |
| Admin Page | `app/admin/error_tracking.rb` | ActiveAdmin interface |

### Error Flow

1. Exception occurs in application code
2. `ErrorTracking.capture_exception(exception, context)` is called
3. PII is scrubbed from context
4. `ErrorAggregator.track()` generates a fingerprint and stores/updates the error
5. The in-memory `ErrorTracker` is also updated for real-time dashboard stats

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SENTRY_DSN` | Sentry DSN for external reporting | _(disabled)_ |
| `APP_RELEASE` | Release tag for error grouping | `eaglespy@5.0.0` |
| `RAILS_ENV` | Environment tag | `development` |
| `HOSTNAME` | Server name tag | System hostname |

### PII Scrubbing

The following fields are automatically scrubbed from error context:
- `password`, `password_confirmation`
- `token`, `api_key`, `secret`
- `authorization`, `cookie`, `session_id`
- `credit_card`, `ssn`

## API Endpoints

### List Errors (Grouped)

```
GET /api/errors
```

**Parameters:**
- `status` - Filter by status: `open`, `resolved`, `ignored`
- `limit` - Max results (default: 50)
- `order` - Sort: `recent` (default) or `frequent`

**Response:**
```json
{
  "errors": [
    {
      "id": 1,
      "fingerprint": "abc123...",
      "error_class": "ActiveRecord::ConnectionTimeout",
      "message": "Connection timed out",
      "count": 42,
      "status": "open",
      "first_seen_at": "2026-02-15T10:00:00Z",
      "last_seen_at": "2026-02-15T14:30:00Z",
      "affected_devices": 5
    }
  ],
  "stats": {
    "total": 100,
    "open": 45,
    "resolved": 50,
    "ignored": 5,
    "total_occurrences": 1234
  }
}
```

### Error Details

```
GET /api/errors/:id
```

Returns full error details including backtrace and device IDs.

### Resolve Error

```
PUT /api/errors/:id/resolve
```

### Ignore Error

```
PUT /api/errors/:id/ignore
```

## Admin Interface

Navigate to **🐛 Error Tracking** in the admin sidebar to:

- View all tracked errors with filtering by status, class, date range
- See error statistics in the sidebar
- Resolve or ignore individual errors
- Batch resolve/ignore multiple errors
- View full backtrace and affected devices

## Error Fingerprinting

Errors are grouped by a SHA-256 fingerprint generated from:
- Exception class name
- Normalized error message (numbers → `N`, quoted strings → `"..."`)
- First 3 backtrace lines

This ensures similar errors are grouped together even if messages differ slightly.

## Auto-Resolution

Errors that haven't occurred in 7 days are automatically resolved. Run the cleanup manually:

```ruby
ErrorAggregator.auto_resolve_stale!
```

Or schedule it via cron/whenever.

## Usage in Code

### Capture an exception

```ruby
begin
  risky_operation
rescue => e
  ErrorTracking.capture_exception(e, device_id: device.id)
end
```

### Add breadcrumbs

```ruby
ErrorTracking.add_breadcrumb('user_action', 'clicked_button', { button: 'submit' })
```

### Get aggregated stats

```ruby
ErrorAggregator.stats
# => { total: 100, open: 45, resolved: 50, ignored: 5, ... }
```
