class DataRetentionService < ApplicationService
  # Configurable retention periods (in days) per data type
  DEFAULT_RETENTION_PERIODS = {
    keylogs: 90,
    keylog_screenshots: 90,
    geo_locations: 30,
    sms_messages: 180,
    call_logs: 180,
    contacts: 365,
    pictures: 60,
    screenshots: 60,
    recordings: 30,
    device_notifications: 60,
    notification_media: 60,
    messaging_apps_dumps: 90,
    geofence_events: 30
  }.freeze

  DATA_TYPE_MODELS = {
    keylogs: Keylog,
    keylog_screenshots: KeylogScreenshot,
    geo_locations: GeoLocation,
    sms_messages: SmsMessage,
    call_logs: CallLog,
    contacts: Contact,
    pictures: Picture,
    screenshots: Screenshot,
    recordings: Recording,
    device_notifications: DeviceNotification,
    notification_media: NotificationMedia,
    messaging_apps_dumps: MessagingAppsDump,
    geofence_events: GeofenceEvent
  }.freeze

  def initialize(smartphone: nil, overrides: {})
    @smartphone = smartphone
    @retention_periods = DEFAULT_RETENTION_PERIODS.merge(overrides.symbolize_keys)
  end

  def call
    enforce_all_policies
  end

  # Enforce retention for all data types, returns summary
  def enforce_all_policies
    summary = { enforced_at: Time.current, deleted: {}, errors: [] }

    @retention_periods.each do |data_type, retention_days|
      result = enforce_policy(data_type, retention_days)
      if result.success?
        summary[:deleted][data_type] = result.value
      else
        summary[:errors] << { data_type: data_type, error: result.error }
      end
    end

    summary[:total_deleted] = summary[:deleted].values.sum
    log_enforcement(summary)

    Result.success(summary)
  rescue => e
    Rails.logger.error("[DataRetentionService] Enforcement failed: #{e.message}")
    Result.failure(e.message)
  end

  # Enforce retention for a single data type
  def enforce_policy(data_type, retention_days = nil)
    retention_days ||= @retention_periods[data_type.to_sym]
    model = DATA_TYPE_MODELS[data_type.to_sym]

    return Result.failure("Unknown data type: #{data_type}") unless model
    return Result.failure("No retention period for: #{data_type}") unless retention_days

    cutoff_date = retention_days.days.ago
    scope = expired_scope(model, cutoff_date)
    count = scope.count

    if count > 0
      delete_in_batches(scope, data_type)
      audit_deletion(data_type, count, retention_days)
    end

    Result.success(count)
  rescue => e
    Rails.logger.error("[DataRetentionService] Failed to enforce #{data_type}: #{e.message}")
    Result.failure(e.message)
  end

  # Return current retention policy configuration
  def current_policy
    @retention_periods.transform_values { |days| { retention_days: days, cutoff_date: days.days.ago.iso8601 } }
  end

  # Update retention period for a data type
  def update_policy(data_type, retention_days)
    data_type = data_type.to_sym
    return Result.failure("Unknown data type: #{data_type}") unless DATA_TYPE_MODELS.key?(data_type)
    return Result.failure("Retention days must be positive") unless retention_days.to_i > 0

    @retention_periods[data_type] = retention_days.to_i

    AuditService.log(
      action: 'update',
      auditable: @smartphone,
      metadata: { gdpr_action: 'retention_policy_update', data_type: data_type, retention_days: retention_days }
    )

    Result.success(@retention_periods)
  rescue => e
    Result.failure(e.message)
  end

  private

  def expired_scope(model, cutoff_date)
    scope = model.where('created_at < ?', cutoff_date)
    scope = scope.where(smartphone_id: @smartphone.id) if @smartphone && model.column_names.include?('smartphone_id')
    scope = scope.where(device_id: @smartphone.device_id) if @smartphone && !model.column_names.include?('smartphone_id') && model.column_names.include?('device_id')
    scope
  end

  def delete_in_batches(scope, data_type, batch_size: 1000)
    loop do
      deleted = scope.limit(batch_size).delete_all
      break if deleted < batch_size
    end
  end

  def audit_deletion(data_type, count, retention_days)
    AuditService.log(
      action: 'delete',
      auditable: @smartphone,
      metadata: {
        gdpr_action: 'data_retention_enforcement',
        data_type: data_type.to_s,
        records_deleted: count,
        retention_days: retention_days,
        cutoff_date: retention_days.days.ago.iso8601,
        device_id: @smartphone&.id
      }
    )
  rescue => e
    Rails.logger.error("[DataRetentionService] Audit logging failed: #{e.message}")
  end

  def log_enforcement(summary)
    Rails.logger.info(
      "[DataRetentionService] Enforcement complete: #{summary[:total_deleted]} records deleted " \
      "across #{summary[:deleted].count} data types"
    )
  end
end
