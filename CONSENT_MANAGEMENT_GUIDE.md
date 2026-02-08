# Consent Management System - GDPR Compliance Guide

## Overview

The Consent Management System provides comprehensive GDPR-compliant consent tracking, Terms of Service (ToS) acceptance, usage disclosure, and consent withdrawal mechanisms for device monitoring operations.

## Features

### 1. Device Consent Tracking
- Granular consent types (monitoring, location, microphone, camera, SMS, calls)
- Complete audit trail with timestamps, IP addresses, and user identifiers
- Version tracking for consent forms
- Consent revocation with automatic operation termination

### 2. Terms of Service Acceptance
- Version-based ToS tracking
- Acceptance timestamps and metadata
- User agent and IP logging
- Historical acceptance records

### 3. Data Usage Disclosures
- Initial, update, and annual disclosures
- Acknowledgment tracking
- Disclosure content versioning

### 4. Consent Enforcement Middleware
- Automatic enforcement of consent requirements
- Protected endpoint validation
- Real-time consent checks
- HTTP 403 responses for missing consents

## GDPR Compliance Features

✅ **Lawfulness, Fairness & Transparency (Art. 5.1.a)**
- Clear consent text shown to users
- Version tracking ensures users see exact consent terms
- Full audit trail of all consent actions

✅ **Purpose Limitation (Art. 5.1.b)**
- Granular consent types for specific purposes
- Separate consents for different data processing activities

✅ **Data Minimization (Art. 5.1.c)**
- Only collect consent data necessary for compliance
- Structured consent metadata

✅ **Right to Withdraw Consent (Art. 7.3)**
- Easy consent revocation via API
- Automatic termination of related operations
- Admin notifications on revocation

✅ **Accountability (Art. 5.2)**
- Complete audit trail with AuditService integration
- Export functionality for compliance reporting
- Timestamped records with user attribution

## Database Schema

### device_consents
Tracks individual consent grants and revocations:
- `consent_type`: Type of consent (device_monitoring, location_tracking, etc.)
- `granted`: Boolean flag for active consent
- `granted_at`, `revoked_at`: Temporal tracking
- `granted_by`: User who granted consent
- `ip_address`: IP from which consent was granted
- `consent_text`: Exact text shown to user
- `consent_version`: Version of consent form
- `metadata`: Additional context (JSON)

### terms_acceptances
Tracks ToS acceptances:
- `terms_version`: Version identifier
- `terms_text`: Full ToS content
- `accepted`: Boolean flag
- `accepted_at`: Timestamp
- `ip_address`, `user_agent`: Request metadata

### data_usage_disclosures
Tracks data usage disclosures:
- `disclosure_type`: initial, update, or annual
- `disclosure_content`: Full disclosure text
- `disclosed_at`, `acknowledged_at`: Timestamps
- `acknowledged`: Boolean flag

## API Endpoints

### List Consent Status
```
GET /apk_installations/:device_id/consents
```

Returns all consent types and their current status.

**Response:**
```json
[
  {
    "type": "device_monitoring",
    "granted": true,
    "granted_at": "2024-01-15T10:30:00Z",
    "revoked_at": null
  },
  {
    "type": "location_tracking",
    "granted": false,
    "granted_at": null,
    "revoked_at": null
  }
]
```

### Grant Consent
```
POST /apk_installations/:device_id/consents/grant
```

**Parameters:**
- `consent_type` (required): One of the CONSENT_TYPES

**Example:**
```bash
curl -X POST http://localhost:3000/apk_installations/1/consents/grant \
  -H "Content-Type: application/json" \
  -d '{"consent_type": "device_monitoring"}'
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "consent_type": "device_monitoring",
    "granted": true,
    "granted_at": "2024-01-15T10:30:00Z",
    "granted_by": "admin@example.com",
    "consent_version": "1.0"
  },
  "message": "Consent granted"
}
```

### Revoke Consent
```
POST /apk_installations/:device_id/consents/revoke
```

**Parameters:**
- `consent_type` (required): Consent type to revoke

**Example:**
```bash
curl -X POST http://localhost:3000/apk_installations/1/consents/revoke \
  -H "Content-Type: application/json" \
  -d '{"consent_type": "microphone_access"}'
```

**Response:**
```json
{
  "data": {
    "id": 3,
    "consent_type": "microphone_access",
    "granted": false,
    "revoked_at": "2024-01-15T11:45:00Z"
  },
  "message": "Consent revoked"
}
```

### Export Consent History
```
GET /apk_installations/:device_id/consents/export
```

Downloads a JSON file with complete consent history including:
- All device consents
- Terms acceptances
- Data usage disclosures

## Consent Types

The system supports the following consent types:

1. **device_monitoring**: General device monitoring
2. **location_tracking**: GPS/location tracking
3. **data_collection**: General data collection
4. **microphone_access**: Microphone recording
5. **camera_access**: Camera usage
6. **sms_monitoring**: SMS message monitoring
7. **call_logging**: Call log tracking

## Consent Enforcement

The `ConsentEnforcement` middleware automatically protects sensitive endpoints:

### Protected Endpoints
- `/location` → requires `location_tracking` consent
- `/microphone` → requires `microphone_access` consent
- `/camera` → requires `camera_access` consent
- `/sms` → requires `sms_monitoring` consent

### Enforcement Behavior
1. Request arrives at protected endpoint
2. Middleware extracts device_id from URL/params
3. Checks if required consent is active
4. Returns 403 if consent missing:
   ```json
   {
     "error": "Consent required: microphone_access",
     "code": "CONSENT_REQUIRED"
   }
   ```
5. Proceeds normally if consent granted

## Service Layer

### ConsentService

Main service for consent operations:

```ruby
# Initialize with device
service = ConsentService.new(device)

# Grant consent
result = service.grant_consent('location_tracking', 
  granted_by: 'admin@example.com',
  ip_address: '192.168.1.100'
)

# Check consent
if service.check_consent('camera_access')
  # Proceed with camera operation
end

# Revoke consent (automatically stops related operations)
service.revoke_consent('microphone_access')

# Get all consent statuses
statuses = service.consent_status

# Export complete history
history = service.export_consent_history
```

## Automatic Operation Termination

When consent is revoked, related operations are automatically stopped:

```ruby
# In ConsentService#stop_related_operations
case consent_type
when 'location_tracking'
  DeviceCommandService.call(device, 'stop_location_tracking')
when 'microphone_access'
  DeviceCommandService.call(device, 'stop_microphone')
when 'camera_access'
  DeviceCommandService.call(device, 'stop_camera')
end
```

## Audit Trail Integration

All consent changes are logged via AuditService:

```ruby
AuditService.log(
  action: 'granted', # or 'revoked'
  auditable: consent_object,
  metadata: {
    consent_type: 'location_tracking',
    device_id: 123,
    granted_by: 'admin@example.com'
  }
)
```

## Admin Notifications

Admins are notified when consent is revoked:

```ruby
AdminMailer.consent_revoked(consent).deliver_later
```

## Configuration

### Environment Variables

```bash
# Consent form version (default: 1.0)
CONSENT_VERSION=1.0
```

### Localization

Consent texts can be localized in `config/locales/consents.yml`:

```yaml
en:
  consents:
    device_monitoring:
      text: "I consent to device monitoring for security purposes..."
    location_tracking:
      text: "I consent to location tracking..."
    # ... etc
```

## Best Practices

### 1. Always Check Consent Before Operations
```ruby
def start_location_tracking
  service = ConsentService.new(@device)
  return error_response unless service.check_consent('location_tracking')
  
  # Proceed with operation
end
```

### 2. Version Your Consent Forms
Update `CONSENT_VERSION` when consent text changes and re-prompt users.

### 3. Export Regularly for Compliance
Schedule regular exports for audit purposes:
```ruby
# In rake task or scheduled job
devices.each do |device|
  ConsentService.new(device).export_consent_history
end
```

### 4. Document All Consent Changes
Use meaningful commit messages when updating consent texts or types.

### 5. Test Consent Enforcement
```ruby
# In RSpec
it 'denies access without consent' do
  get "/apk_installations/#{device.id}/location"
  expect(response).to have_http_status(:forbidden)
  expect(json['error']).to include('Consent required')
end
```

## Migration Guide

### Running the Migration

```bash
# Development
rails db:migrate

# Production
RAILS_ENV=production rails db:migrate
```

### Rollback (if needed)
```bash
rails db:rollback STEP=1
```

## Testing

### Model Specs
```ruby
describe DeviceConsent do
  it 'grants consent with audit trail' do
    consent.grant!(
      granted_by: 'admin@example.com',
      ip_address: '127.0.0.1',
      consent_text: 'Sample text',
      version: '1.0'
    )
    expect(consent.active?).to be true
  end
  
  it 'revokes consent' do
    consent.revoke!
    expect(consent.active?).to be false
  end
end
```

### Controller Specs
```ruby
describe ConsentsController do
  it 'grants consent' do
    post :grant, params: { 
      device_id: device.id, 
      consent_type: 'location_tracking' 
    }
    expect(response).to have_http_status(:created)
  end
end
```

### Middleware Specs
```ruby
describe ConsentEnforcement do
  it 'blocks requests without consent' do
    get "/apk_installations/#{device.id}/location"
    expect(response).to have_http_status(:forbidden)
  end
  
  it 'allows requests with consent' do
    create_consent(device, 'location_tracking', granted: true)
    get "/apk_installations/#{device.id}/location"
    expect(response).to have_http_status(:ok)
  end
end
```

## Troubleshooting

### Issue: Consent not being enforced
**Solution**: Check middleware order in `config/application.rb`. ConsentEnforcement should be after authentication middlewares.

### Issue: 500 error on consent grant
**Solution**: Ensure AuditService exists or handle gracefully in DeviceConsent model.

### Issue: Operations not stopping on revocation
**Solution**: Verify DeviceCommandService exists and implements stop commands.

## Security Considerations

1. **IP Logging**: All consent actions log IP addresses for non-repudiation
2. **Immutable History**: Never delete consent records; only add new entries
3. **Version Control**: Always track consent form versions
4. **Access Control**: Ensure only authorized admins can grant/revoke consents
5. **HTTPS Only**: Enforce HTTPS in production for consent endpoints

## Compliance Checklist

- [ ] Consent forms clearly explain data usage
- [ ] Consent version updated in environment variables
- [ ] Audit trail active and logging
- [ ] Export functionality tested
- [ ] Admin notifications configured
- [ ] Middleware protecting sensitive endpoints
- [ ] Consent texts localized (if multi-language)
- [ ] Regular consent export scheduled
- [ ] Legal team reviewed consent texts
- [ ] Privacy policy updated to reference consent system

## Further Reading

- [GDPR Art. 7 - Conditions for consent](https://gdpr-info.eu/art-7-gdpr/)
- [GDPR Art. 13 - Information to be provided](https://gdpr-info.eu/art-13-gdpr/)
- [GDPR Art. 17 - Right to erasure](https://gdpr-info.eu/art-17-gdpr/)

## Support

For issues or questions:
1. Check audit logs: `AuditLog.where(auditable_type: 'DeviceConsent')`
2. Review middleware logs: `grep ConsentEnforcement log/production.log`
3. Export consent history for analysis

---

**Last Updated**: 2024-01-15  
**Version**: 1.0  
**Maintainer**: EagleSpy Development Team
