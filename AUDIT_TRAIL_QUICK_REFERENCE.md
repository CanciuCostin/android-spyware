# Audit Trail System - Quick Reference

## 🚀 Quick Start

```bash
# 1. Install dependencies
bundle install

# 2. Run migration
rails db:migrate

# 3. Verify setup
rails audit:verify

# 4. Access web interface
# http://localhost:3000/audit_logs
```

## 📝 Enable Auditing

```ruby
# Just include the concern in any model
class YourModel < ApplicationRecord
  include Auditable
end
```

## 🔍 Query Audit Logs

```ruby
# By user
AuditLog.by_admin(user_id).recent

# By action
AuditLog.by_action('create').recent

# By resource type
AuditLog.by_type('ApkInstallation').recent

# Date range
AuditLog.in_date_range(30.days.ago, Date.today).recent

# Combined search
AuditLog.search(
  admin_user_id: 1,
  action: 'update',
  auditable_type: 'ApkInstallation',
  start_date: '2026-01-01',
  end_date: '2026-12-31'
)
```

## 📊 Reporting

```bash
# Generate compliance report
rails audit:report

# Custom date range
rails audit:report['2026-01-01','2026-12-31']

# Export to CSV
rails audit:export['2026-01-01','2026-12-31','report.csv']

# Verify integrity
rails audit:verify
```

## 🌐 Web Interface

```
GET /audit_logs                 # List all logs
GET /audit_logs/:id             # View single log
GET /audit_logs/stats           # Statistics
GET /audit_logs/export.csv      # Export as CSV
GET /audit_logs/export.json     # Export as JSON
```

### Filters
```
?action=create                  # Filter by action
?auditable_type=ApkInstallation # Filter by resource
?admin_user_id=1                # Filter by user
?start_date=2026-01-01          # Date range start
?end_date=2026-12-31            # Date range end
```

## 🔒 Security Features

✅ **Immutable**: Database trigger prevents UPDATE/DELETE  
✅ **Filtered**: Passwords and tokens automatically excluded  
✅ **Verified**: Integrity check detects tampering  
✅ **Compliant**: Meets SOC 2, GDPR, HIPAA, PCI DSS, ISO 27001  

## 💡 Manual Logging

```ruby
# Log any action
AuditService.log(
  action: 'read',
  auditable: @device,
  admin_user: current_admin_user,
  changes: {},
  metadata: { query: params[:q] }
)

# Log without resource
AuditService.log(
  action: 'export',
  admin_user: current_admin_user,
  metadata: { format: 'csv', count: 1000 }
)
```

## 🎯 Actions

- `create` - Resource created
- `read` - Resource viewed/accessed
- `update` - Resource modified
- `delete` - Resource deleted
- `login` - User logged in
- `logout` - User logged out

## 📚 Documentation

See `AUDIT_TRAIL.md` for comprehensive guide including:
- Architecture details
- Security features
- Compliance standards
- Integration examples
- Testing examples
- Troubleshooting guide

## ⚙️ Configuration

### Enable for Model
```ruby
class Device < ApplicationRecord
  include Auditable
end
```

### Custom Metadata
```ruby
AuditService.log(
  action: 'export',
  metadata: {
    format: 'csv',
    record_count: @devices.count,
    filters_applied: params[:filters]
  }
)
```

### Current Request Context
Available automatically in RequestStore:
- `current_admin_user` - Admin who made the request
- `current_ip_address` - IP address
- `current_user_agent` - Browser/client
- `request_params` - Filtered parameters
- `request_method` - HTTP method
- `request_path` - URL path
- `response_status` - HTTP status code

## 🔧 Troubleshooting

### Logs not being created?
1. Check middleware is loaded: `config/application.rb`
2. Check RequestStore has current_admin_user
3. Check Rails logs for exceptions

### "Audit logs are immutable" error?
This is expected! It means immutability is working.

### Missing request context?
1. Verify AuditMiddleware is registered
2. Check RequestStore is populated in middleware

## 📈 Performance

### Current: Synchronous
- Suitable for most workloads
- Indexed queries for fast retrieval
- Pagination for large result sets

### High Load: Asynchronous (Optional)
```ruby
class AuditService
  def self.log_async(...)
    AuditLogJob.perform_later(...)
  end
end
```

## ✅ Verification

```bash
# Run verification script
.\scripts\verify_audit_trail.ps1

# Or manually check:
rails db:migrate:status | grep audit  # Migration status
rails audit:verify                    # Integrity check
rails console                         # Test in console
```

## 🎓 Examples

### View user's activity
```ruby
user = AdminUser.find_by(email: 'admin@example.com')
AuditLog.by_admin(user.id).recent.limit(20)
```

### Track deletions
```ruby
AuditLog.by_action('delete').recent
```

### Find who modified a resource
```ruby
AuditLog.where(auditable_type: 'AlertRule', auditable_id: 123)
```

### Daily activity report
```ruby
logs = AuditLog.where('created_at >= ?', Date.today)
logs.group(:action).count
```

---

**Need Help?** See `AUDIT_TRAIL.md` for complete documentation.
