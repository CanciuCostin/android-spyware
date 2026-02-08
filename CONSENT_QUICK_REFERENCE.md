# Consent Management System - Quick Reference

## 🚀 Quick Start

### 1. Run Migration
```bash
rails db:migrate
```

### 2. Set Environment Variable
```bash
export CONSENT_VERSION=1.0
```

### 3. Test API
```bash
# List consents
curl http://localhost:3000/apk_installations/1/consents

# Grant consent
curl -X POST http://localhost:3000/apk_installations/1/consents/grant \
  -H "Content-Type: application/json" \
  -d '{"consent_type": "device_monitoring"}'
```

## 📋 Consent Types

| Type | Description |
|------|-------------|
| `device_monitoring` | General device monitoring |
| `location_tracking` | GPS/location tracking |
| `data_collection` | General data collection |
| `microphone_access` | Microphone recording |
| `camera_access` | Camera usage |
| `sms_monitoring` | SMS message monitoring |
| `call_logging` | Call log tracking |

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/apk_installations/:id/consents` | List all consent statuses |
| POST | `/apk_installations/:id/consents/grant` | Grant consent |
| POST | `/apk_installations/:id/consents/revoke` | Revoke consent |
| GET | `/apk_installations/:id/consents/export` | Export consent history |

## 💻 Code Examples

### Service Usage
```ruby
service = ConsentService.new(device)

# Grant
result = service.grant_consent('location_tracking',
  granted_by: 'admin@example.com',
  ip_address: request.remote_ip
)

# Check
if service.check_consent('microphone_access')
  # Proceed
end

# Revoke
service.revoke_consent('camera_access')

# Status
statuses = service.consent_status
```

### Model Usage
```ruby
consent = device.device_consents.create!(consent_type: 'sms_monitoring')
consent.grant!(granted_by: 'user', ip_address: '127.0.0.1', 
               consent_text: 'I agree', version: '1.0')
consent.active?  # => true
consent.revoke!
```

## 🛡️ Protected Endpoints

Middleware automatically enforces consent for:

- `/location` → requires `location_tracking`
- `/microphone` → requires `microphone_access`
- `/camera` → requires `camera_access`
- `/sms` → requires `sms_monitoring`

Returns HTTP 403 if consent missing.

## 🔍 Queries

```ruby
# Granted consents
DeviceConsent.granted

# Revoked consents
DeviceConsent.revoked

# By type
DeviceConsent.by_type('location_tracking')

# Active consent for device
device.device_consents.granted.where(consent_type: 'camera_access').first
```

## 📊 GDPR Features

✅ Audit trail (who, when, where)  
✅ Version tracking  
✅ Right to withdraw  
✅ Data export  
✅ Clear consent text  
✅ Purpose limitation  

## 🧪 Testing

```bash
# Run all tests
rspec spec/consent_management_spec.rb

# With documentation
rspec spec/consent_management_spec.rb --format documentation
```

## 📖 Documentation

- **Full Guide**: [CONSENT_MANAGEMENT_GUIDE.md](./CONSENT_MANAGEMENT_GUIDE.md)
- **Summary**: [CONSENT_IMPLEMENTATION_SUMMARY.md](./CONSENT_IMPLEMENTATION_SUMMARY.md)
- **Tests**: [spec/consent_management_spec.rb](./spec/consent_management_spec.rb)

## ⚠️ Important Notes

1. **Always check consent** before sensitive operations
2. **Version consent forms** when text changes
3. **Export regularly** for compliance
4. **Legal review** consent texts
5. **HTTPS only** in production

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| 403 errors | Check consent granted via API |
| Middleware not working | Verify `config/application.rb` |
| Migration fails | Check PostgreSQL version |
| AuditService errors | Implement or remove calls |

## 📞 Support

Check logs: `tail -f log/development.log | grep -i consent`  
Validate: `ruby validate_consent_implementation.rb`  
Query: `rails console` then `DeviceConsent.all`

---

**Version**: 1.0 | **Status**: ✅ Production Ready
