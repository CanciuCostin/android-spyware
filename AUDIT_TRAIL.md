# Audit Trail System Documentation

## Overview

The Audit Trail system provides comprehensive tracking of all admin actions with immutable logs for compliance, security, and accountability. Every create, update, delete, and login action is automatically logged with full context including user, IP address, timestamp, and detailed changes.

## Key Features

### 1. Immutable Logs
- **Database-level immutability**: PostgreSQL trigger prevents any UPDATE or DELETE operations on audit logs
- **Rails-level protection**: Model callbacks prevent modification attempts at the application level
- **Integrity verification**: Rake tasks to verify log sequence and detect tampering attempts

### 2. Comprehensive Tracking
- **User actions**: All admin user operations (create, update, delete)
- **Resource changes**: Full before/after state for all modifications
- **Request context**: IP address, user agent, request path, HTTP method, response status
- **Metadata**: Session ID, environment, timestamps

### 3. Automatic Auditing
- **Model concern**: Include `Auditable` concern to enable automatic audit logging
- **No code changes**: Works transparently with existing models
- **Selective auditing**: Only include models that require auditing

### 4. Compliance Reporting
- **Built-in reports**: Generate compliance reports by date range
- **Multiple formats**: Export as CSV, JSON, or formatted text
- **Analytics**: Activity stats by user, action type, resource type, and time period

## Database Schema

```ruby
create_table :audit_logs do |t|
  t.references :admin_user, foreign_key: true
  t.string :action, null: false          # 'create', 'update', 'delete', 'read', 'login', 'logout'
  t.string :auditable_type               # Polymorphic: Model name
  t.bigint :auditable_id                 # Polymorphic: Record ID
  t.json :changes, default: {}           # Before/after values
  t.json :metadata, default: {}          # Additional context
  t.string :ip_address                   # Request IP
  t.string :user_agent                   # Browser/client
  t.text :request_params                 # Sanitized request params
  t.string :request_method               # GET, POST, PUT, DELETE, etc.
  t.string :request_path                 # Request URL path
  t.integer :response_status             # HTTP status code
  t.timestamps
end
```

**Indexes:**
- `created_at` - Fast chronological queries
- `[admin_user_id, created_at]` - User activity timeline
- `[auditable_type, auditable_id]` - Resource history
- `action` - Filter by action type

**Immutability Trigger:**
```sql
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
    RAISE EXCEPTION 'Audit logs are immutable';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();
```

## Usage

### 1. Enable Auditing for a Model

```ruby
class YourModel < ApplicationRecord
  include Auditable
  
  # That's it! All create/update/delete operations are now audited
end
```

### 2. Manual Audit Logging

```ruby
# Log a custom action
AuditService.log(
  action: 'read',
  auditable: @device,
  admin_user: current_admin_user,
  changes: {},
  metadata: { query: params[:q], filters: params[:filters] }
)

# Log without a specific resource
AuditService.log(
  action: 'export',
  admin_user: current_admin_user,
  metadata: { format: 'csv', record_count: 1000 }
)
```

### 3. Query Audit Logs

```ruby
# All logs for a user
AuditLog.by_admin(admin_user_id).recent

# All create actions
AuditLog.by_action('create').recent

# All changes to a specific resource
AuditLog.where(auditable: @device).recent

# Date range
AuditLog.in_date_range(30.days.ago, Date.today).recent

# Combined search
AuditLog.search(
  admin_user_id: params[:admin_user_id],
  action: 'update',
  auditable_type: 'ApkInstallation',
  start_date: '2026-01-01',
  end_date: '2026-12-31'
)
```

### 4. View Audit Logs (Web UI)

**Index page with filters:**
```
GET /audit_logs
GET /audit_logs?admin_user_id=1
GET /audit_logs?action=update
GET /audit_logs?auditable_type=ApkInstallation
GET /audit_logs?start_date=2026-01-01&end_date=2026-12-31
```

**Individual log:**
```
GET /audit_logs/:id
```

**Statistics:**
```
GET /audit_logs/stats
GET /audit_logs/stats?start_date=2026-01-01&end_date=2026-12-31
```

**Export:**
```
GET /audit_logs/export.csv
GET /audit_logs/export.json
```

### 5. Generate Compliance Reports

```bash
# Generate report for last 30 days
rails audit:report

# Custom date range
rails audit:report['2026-01-01','2026-12-31']

# Export to CSV
rails audit:export['2026-01-01','2026-12-31','compliance_report.csv']

# Verify integrity
rails audit:verify
```

## Compliance Report Example

```
================================================================================
Audit Trail Compliance Report
================================================================================
Period: 2026-01-01 to 2026-12-31
Generated: 2026-02-08T14:08:55Z
================================================================================

SUMMARY
--------------------------------------------------------------------------------
Total actions logged: 15,432
Unique admin users: 12
Unique IP addresses: 25

ACTIONS BY TYPE
--------------------------------------------------------------------------------
  read           :    8,234 (53.35%)
  update         :    4,521 (29.30%)
  create         :    1,876 (12.16%)
  delete         :      543 (3.52%)
  login          :      258 (1.67%)

ACTIONS BY USER
--------------------------------------------------------------------------------
  admin@example.com                        :    5,432
  security.admin@example.com               :    3,876
  operator1@example.com                    :    2,543
  ...

ACTIONS BY RESOURCE TYPE
--------------------------------------------------------------------------------
  ApkInstallation                   :    3,456
  AlertRule                         :    1,234
  DeviceGroup                       :      876
  NotificationChannel               :      543
  ...

TOP IP ADDRESSES
--------------------------------------------------------------------------------
  192.168.1.100       :    8,234
  10.0.0.50           :    4,521
  ...

DAILY ACTIVITY
--------------------------------------------------------------------------------
  2026-01-01 |    234 | ################
  2026-01-02 |    187 | #############
  2026-01-03 |    298 | ####################
  ...
```

## Security Features

### 1. Immutability Enforcement
- **Database trigger**: Prevents UPDATE/DELETE at PostgreSQL level
- **Rails model**: Raises `ActiveRecord::ReadOnlyRecord` on modification attempts
- **Verification task**: Detects missing IDs (potential deletion attempts)

### 2. Sensitive Data Protection
- **Automatic filtering**: Removes passwords, tokens, and authentication data
- **Configurable exclusions**: Easy to add fields to exclude
- **Encrypted storage**: Can be combined with database encryption

### 3. Access Control
- **Authentication required**: Only authenticated admins can view logs
- **Read-only interface**: No delete/update endpoints exposed
- **Export restrictions**: Limit export to authorized users

### 4. Integrity Verification

```bash
rails audit:verify
```

Output:
```
Verifying audit log integrity...

Total audit logs: 15,432
✓ No missing IDs detected - log sequence intact
✓ All logs have required fields
Found 87 logs referencing deleted resources (expected behavior)

Integrity check complete
```

## Architecture

### Components

1. **AuditMiddleware**: Captures request context (IP, user agent, params, etc.)
2. **AuditService**: Core service for creating audit log entries
3. **Auditable Concern**: Automatic auditing for ActiveRecord models
4. **AuditLog Model**: Immutable log storage with validation
5. **AuditLogsController**: Web interface for viewing and exporting logs
6. **Rake Tasks**: Compliance reporting and verification

### Request Flow

```
[HTTP Request] 
    ↓
[AuditMiddleware] → Stores request context in RequestStore
    ↓
[Controller/Model] → Performs action
    ↓
[Auditable Concern] → Triggers after_create/update/destroy
    ↓
[AuditService] → Enriches with metadata
    ↓
[AuditLog.create!] → Writes immutable log
    ↓
[PostgreSQL Trigger] → Enforces immutability
```

### Data Flow

```
RequestStore (thread-local)
    - current_admin_user
    - current_ip_address
    - current_user_agent
    - request_params (filtered)
    - request_method
    - request_path
    - response_status
    - session_id

↓ (accessed by AuditService)

AuditLog Record
    - Links to admin_user
    - Links to auditable resource
    - Captures changes (before/after)
    - Stores enriched metadata
    - Includes full request context
```

## Performance Considerations

### 1. Asynchronous Logging (Recommended for High Load)

```ruby
# config/initializers/audit_trail.rb
class AuditService
  def self.log_async(...)
    AuditLogJob.perform_later(...)
  end
end

# app/jobs/audit_log_job.rb
class AuditLogJob < ApplicationJob
  queue_as :audit
  
  def perform(action:, auditable:, admin_user:, changes:, metadata:)
    AuditService.log(
      action: action,
      auditable: auditable,
      admin_user: admin_user,
      changes: changes,
      metadata: metadata
    )
  end
end
```

### 2. Indexing Strategy
- Default indexes cover common queries (user, date, action, resource)
- Add custom indexes for specific access patterns
- Consider partitioning for very large datasets (100M+ records)

### 3. Archival Strategy
- Keep recent logs (last 365 days) in hot storage
- Archive older logs to cold storage or data warehouse
- Use partitioning by date for efficient archival

```ruby
# Example archival task
namespace :audit do
  task :archive, [:days] => :environment do |t, args|
    days = (args[:days] || 365).to_i
    cutoff_date = days.days.ago
    
    # Export to S3/warehouse
    old_logs = AuditLog.where('created_at < ?', cutoff_date)
    
    # Use pg_dump or COPY TO for efficient export
    # Then delete from primary database (if immutability allows)
  end
end
```

## Integration Examples

### 1. ActiveAdmin Integration

```ruby
# app/admin/audit_logs.rb
ActiveAdmin.register AuditLog do
  menu priority: 99, label: "Audit Trail"
  
  actions :index, :show
  
  filter :admin_user
  filter :action, as: :select, collection: %w[create read update delete login logout]
  filter :auditable_type
  filter :created_at
  
  index do
    selectable_column
    id_column
    column :admin_user
    column :action
    column :auditable do |log|
      "#{log.auditable_type} ##{log.auditable_id}" if log.auditable_type
    end
    column :ip_address
    column :created_at
    actions
  end
  
  show do
    attributes_table do
      row :id
      row :admin_user
      row :action
      row :auditable
      row :changes do |log|
        pre JSON.pretty_generate(log.changes)
      end
      row :metadata do |log|
        pre JSON.pretty_generate(log.metadata)
      end
      row :ip_address
      row :user_agent
      row :request_method
      row :request_path
      row :response_status
      row :created_at
    end
  end
end
```

### 2. GraphQL Integration

```ruby
# app/graphql/types/audit_log_type.rb
module Types
  class AuditLogType < Types::BaseObject
    field :id, ID, null: false
    field :action, String, null: false
    field :admin_user, Types::AdminUserType, null: true
    field :auditable_type, String, null: true
    field :auditable_id, Int, null: true
    field :changes, GraphQL::Types::JSON, null: false
    field :metadata, GraphQL::Types::JSON, null: false
    field :ip_address, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end

# app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    field :audit_logs, [Types::AuditLogType], null: false do
      argument :admin_user_id, ID, required: false
      argument :action, String, required: false
      argument :limit, Int, required: false, default_value: 50
    end
    
    def audit_logs(admin_user_id: nil, action: nil, limit: 50)
      logs = AuditLog.all
      logs = logs.by_admin(admin_user_id) if admin_user_id
      logs = logs.by_action(action) if action
      logs.recent.limit(limit)
    end
  end
end
```

### 3. Webhook Notifications for Critical Actions

```ruby
# config/initializers/audit_trail.rb
class AuditService
  CRITICAL_ACTIONS = %w[delete].freeze
  CRITICAL_RESOURCES = %w[AdminUser AlertRule DeviceGroup].freeze
  
  def log
    audit_log = super
    
    if critical_action?(audit_log)
      notify_security_team(audit_log)
    end
    
    audit_log
  end
  
  private
  
  def critical_action?(log)
    CRITICAL_ACTIONS.include?(log.action) &&
    CRITICAL_RESOURCES.include?(log.auditable_type)
  end
  
  def notify_security_team(log)
    # Send webhook, email, or Slack notification
    NotificationService.send(
      channel: :security,
      message: "Critical action: #{log.admin_user&.email} #{log.action}d #{log.auditable_type} ##{log.auditable_id}"
    )
  rescue => e
    Rails.logger.error "Failed to notify security team: #{e.message}"
  end
end
```

## Testing

### RSpec Examples

```ruby
# spec/services/audit_service_spec.rb
require 'rails_helper'

RSpec.describe AuditService do
  let(:admin_user) { create(:admin_user) }
  let(:device) { create(:apk_installation) }
  
  before do
    RequestStore.store[:current_admin_user] = admin_user
    RequestStore.store[:current_ip_address] = '192.168.1.100'
  end
  
  describe '.log' do
    it 'creates an audit log entry' do
      expect {
        AuditService.log(
          action: 'create',
          auditable: device,
          changes: { after: device.attributes }
        )
      }.to change(AuditLog, :count).by(1)
    end
    
    it 'captures request context' do
      log = AuditService.log(
        action: 'update',
        auditable: device,
        changes: { before: {status: 'pending'}, after: {status: 'installed'} }
      )
      
      expect(log.admin_user).to eq(admin_user)
      expect(log.ip_address).to eq('192.168.1.100')
      expect(log.action).to eq('update')
      expect(log.changes['before']).to eq({'status' => 'pending'})
    end
  end
end

# spec/models/audit_log_spec.rb
require 'rails_helper'

RSpec.describe AuditLog do
  let(:audit_log) { create(:audit_log) }
  
  describe 'immutability' do
    it 'prevents updates' do
      expect {
        audit_log.update(action: 'different_action')
      }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
    
    it 'prevents deletion' do
      expect {
        audit_log.destroy
      }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
  
  describe 'scopes' do
    let!(:create_log) { create(:audit_log, action: 'create') }
    let!(:update_log) { create(:audit_log, action: 'update') }
    
    it 'filters by action' do
      expect(AuditLog.by_action('create')).to contain_exactly(create_log)
    end
    
    it 'orders by recent first' do
      expect(AuditLog.recent.first).to eq(update_log)
    end
  end
end

# spec/models/concerns/auditable_spec.rb
require 'rails_helper'

RSpec.describe Auditable do
  let(:model_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'apk_installations'
      include Auditable
    end
  end
  
  let(:instance) { model_class.create!(target_ip: '192.168.1.100') }
  
  it 'creates audit log on create' do
    expect {
      model_class.create!(target_ip: '192.168.1.101')
    }.to change(AuditLog, :count).by(1)
    
    log = AuditLog.last
    expect(log.action).to eq('create')
  end
  
  it 'creates audit log on update' do
    expect {
      instance.update(target_ip: '192.168.1.102')
    }.to change(AuditLog, :count).by(1)
    
    log = AuditLog.last
    expect(log.action).to eq('update')
    expect(log.changes['before']['target_ip']).to eq('192.168.1.100')
    expect(log.changes['after']['target_ip']).to eq('192.168.1.102')
  end
  
  it 'creates audit log on destroy' do
    instance # Create instance first
    
    expect {
      instance.destroy
    }.to change(AuditLog, :count).by(1)
    
    log = AuditLog.last
    expect(log.action).to eq('delete')
  end
end
```

## Compliance Standards

This audit trail system helps meet requirements for:

- **SOC 2**: System access logging and monitoring
- **GDPR**: Data processing accountability and audit trails
- **HIPAA**: Access logging for protected health information
- **PCI DSS**: Tracking and monitoring access to cardholder data
- **ISO 27001**: Information security event logging

### Key Compliance Features

1. **Who**: Every action linked to authenticated admin user
2. **What**: Detailed record of action type and changes
3. **When**: Precise timestamp (ISO 8601 format)
4. **Where**: IP address and request path
5. **Why**: Optional metadata for context
6. **Immutability**: Cannot be altered or deleted after creation
7. **Retention**: Configurable retention period with archival
8. **Integrity**: Verification tools to detect tampering

## Troubleshooting

### Issue: Audit logs not being created

**Check:**
1. Is RequestStore middleware loaded? Check `config/application.rb`
2. Is `current_admin_user` being set in RequestStore?
3. Check Rails logs for exceptions in AuditService
4. Verify database migration ran successfully

```bash
rails db:migrate:status | grep audit
```

### Issue: "Audit logs are immutable" error

**This is expected!** It means the immutability protection is working. Audit logs cannot be modified after creation.

### Issue: Missing request context (IP, user agent)

**Check:**
1. Is AuditMiddleware registered in application.rb?
2. Is it placed before other middleware that might terminate the request?
3. Check that RequestStore is being populated in middleware

### Issue: Performance degradation

**Solutions:**
1. Move to asynchronous audit logging (use background jobs)
2. Add indexes for common query patterns
3. Consider partitioning audit_logs table by date
4. Archive old logs to cold storage

## Maintenance

### Regular Tasks

```bash
# Weekly: Generate compliance report
rails audit:report['2026-02-01','2026-02-07'] > reports/weekly_audit_$(date +%Y%m%d).txt

# Monthly: Verify integrity
rails audit:verify

# Quarterly: Export for long-term storage
rails audit:export['2026-01-01','2026-03-31','archive/q1_2026.csv']

# Annually: Archive old logs (custom script based on retention policy)
rails audit:archive[730] # Archive logs older than 2 years
```

### Monitoring

Set up alerts for:
- Unusual spike in delete actions
- Failed audit log creation (check Rails logs)
- Missing IDs detected by integrity check
- High-privilege actions (admin user changes)

## Summary

The Audit Trail system provides:

✅ **Comprehensive logging** of all admin actions  
✅ **Immutable records** enforced at database level  
✅ **Rich context** (who, what, when, where, why)  
✅ **Compliance reporting** with multiple export formats  
✅ **Integrity verification** to detect tampering  
✅ **Easy integration** with existing models via concern  
✅ **Performance-friendly** with async option  
✅ **Security-first** design with sensitive data filtering  

For support or questions, contact the security team or file an issue in the project repository.
