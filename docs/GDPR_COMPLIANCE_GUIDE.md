# GDPR Compliance Guide

This guide covers the GDPR (General Data Protection Regulation) compliance features implemented in EagleSpy V5.

## Overview

The GDPR compliance module provides:

- **Data Retention Policies** — Configurable automatic expiration and deletion of data per type
- **Right to Erasure (Art. 17)** — Complete data deletion for a device with erasure certificate
- **Right of Access (Art. 15)** — Full data export in machine-readable JSON format
- **Privacy Policy Generation** — Dynamic privacy policy based on active consent types
- **Audit Trail** — All GDPR actions are logged via `AuditService`

## API Endpoints

All endpoints are under `/api/devices/:id/` and require admin authentication.

### Data Erasure (Art. 17)

```
POST /api/devices/:id/erasure_request
```

Permanently deletes all personal data associated with the device, including:
keylogs, contacts, SMS, call logs, photos, screenshots, recordings, location data,
geofence events, notifications, and physical files.

**Response** includes an erasure certificate with:
- Certificate ID (UUID)
- Data categories erased
- Total records erased
- SHA-256 checksum for integrity verification

### Data Export (Art. 15)

```
GET /api/devices/:id/data_export
GET /api/devices/:id/data_export?format=zip
```

Exports all personal data in JSON format. The ZIP format includes:
- `metadata.json` — Export metadata and data controller information
- `data_dictionary.json` — Description of all data fields
- `data/*.json` — Data files per category
- `README.txt` — Human-readable summary

### Retention Policy

```
GET  /api/devices/:id/retention_policy
PUT  /api/devices/:id/retention_policy
```

View or update data retention periods per data type.

**PUT body example:**

```json
{
  "policies": {
    "keylogs": 60,
    "geo_locations": 14,
    "sms_messages": 90
  }
}
```

### Privacy Policy

```
GET /api/devices/:id/privacy_policy
GET /api/devices/:id/privacy_policy?format=text
```

Generates a privacy policy (HTML by default) based on active consent types for the device.

## Default Retention Periods

| Data Type             | Retention (days) |
|-----------------------|------------------|
| Keylogs               | 90               |
| Keylog Screenshots    | 90               |
| Geo Locations         | 30               |
| SMS Messages          | 180              |
| Call Logs             | 180              |
| Contacts              | 365              |
| Pictures              | 60               |
| Screenshots           | 60               |
| Recordings            | 30               |
| Device Notifications  | 60               |
| Notification Media    | 60               |
| Messaging Apps Dumps  | 90               |
| Geofence Events       | 30               |

## Scheduled Data Retention

The `DataRetentionJob` runs nightly to enforce retention policies. Schedule it with:

### Using ActiveJob / Sidekiq-Cron

```ruby
# config/initializers/sidekiq_cron.rb
Sidekiq::Cron::Job.create(
  name: 'GDPR Data Retention - nightly',
  cron: '0 2 * * *',
  class: 'DataRetentionJob'
)
```

### Using Whenever gem

```ruby
# config/schedule.rb
every 1.day, at: '2:00 am' do
  runner "DataRetentionJob.perform_later"
end
```

### Manual execution

```ruby
# All devices
DataRetentionJob.perform_later

# Specific device
DataRetentionJob.perform_later(smartphone_id: 1)

# With custom retention overrides
DataRetentionJob.perform_later(overrides: { keylogs: 30, geo_locations: 7 })
```

## Services

### DataRetentionService

```ruby
service = DataRetentionService.new(smartphone: device, overrides: { keylogs: 30 })
result = service.enforce_all_policies
# result.value => { enforced_at: ..., deleted: { keylogs: 150, ... }, total_deleted: 320 }
```

### ErasureService

```ruby
service = ErasureService.new(smartphone)
result = service.execute_erasure
# result.value => { device_id: ..., certificate: { certificate_id: "...", checksum: "..." }, ... }
```

### DataExportService

```ruby
service = DataExportService.new(smartphone)
result = service.export_as_json   # In-memory JSON
result = service.export_as_zip    # ZIP file on disk
```

### PrivacyPolicyGenerator

```ruby
generator = PrivacyPolicyGenerator.new(device: apk_installation, format: :html)
result = generator.generate
# result.value => { version: "1.0", content: "<html>...", ... }
```

## Environment Variables

| Variable                | Default               | Description                              |
|-------------------------|-----------------------|------------------------------------------|
| `DATA_CONTROLLER_NAME`  | System Administrator  | Name of the GDPR data controller         |
| `DATA_CONTROLLER_EMAIL` | admin@example.com     | Contact email for the data controller    |
| `CONSENT_VERSION`       | 1.0                   | Current consent form version             |

## Audit Trail

All GDPR actions are logged via `AuditService` with `metadata.gdpr_action`:

- `data_retention_enforcement` — Automatic retention enforcement
- `retention_policy_update` — Retention period changed
- `right_to_erasure` — Device data erased (includes certificate ID)
- `data_export` — Data exported under Art. 15

Query audit logs:

```ruby
AuditLog.where("metadata->>'gdpr_action' IS NOT NULL").recent
```

## File Structure

```
app/
  controllers/api/gdpr_controller.rb    — API endpoints
  services/
    data_retention_service.rb           — Retention policy enforcement
    data_export_service.rb              — GDPR Art. 15 data export
    erasure_service.rb                  — GDPR Art. 17 right to erasure
    privacy_policy_generator.rb         — Dynamic privacy policy
  jobs/
    data_retention_job.rb               — Scheduled retention job
docs/
  GDPR_COMPLIANCE_GUIDE.md             — This file
```
