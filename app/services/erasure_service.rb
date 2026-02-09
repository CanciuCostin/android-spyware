class ErasureService < ApplicationService
  ERASABLE_ASSOCIATIONS = %i[
    keylogs
    keylog_screenshots
    contacts
    sms_messages
    call_logs
    pictures
    screenshots
    recordings
    geo_locations
    messaging_apps_dumps
    geofence_events
    geofences
    pending_commands
  ].freeze

  ERASABLE_DEVICE_MODELS = {
    device_notifications: DeviceNotification,
    notification_media: NotificationMedia
  }.freeze

  def initialize(smartphone)
    @smartphone = smartphone
  end

  def call
    execute_erasure
  end

  def execute_erasure
    erasure_report = { device_id: @smartphone.device_id, started_at: Time.current, deleted: {} }

    ActiveRecord::Base.transaction do
      # Delete associated records via Smartphone associations
      ERASABLE_ASSOCIATIONS.each do |assoc|
        next unless @smartphone.respond_to?(assoc)

        count = @smartphone.public_send(assoc).count
        @smartphone.public_send(assoc).delete_all
        erasure_report[:deleted][assoc] = count
      end

      # Delete device-linked records (by device_id string)
      ERASABLE_DEVICE_MODELS.each do |key, model|
        if model.column_names.include?('device_id')
          count = model.where(device_id: @smartphone.device_id).count
          model.where(device_id: @smartphone.device_id).delete_all
          erasure_report[:deleted][key] = count
        end
      end

      # Clean up physical files
      cleanup_files
    end

    erasure_report[:completed_at] = Time.current
    erasure_report[:total_deleted] = erasure_report[:deleted].values.sum
    erasure_report[:certificate] = generate_erasure_certificate(erasure_report)

    audit_erasure(erasure_report)

    Result.success(erasure_report)
  rescue => e
    Rails.logger.error("[ErasureService] Erasure failed for device #{@smartphone.device_id}: #{e.message}")
    Result.failure(e.message)
  end

  private

  def cleanup_files
    device_dirs = [
      Rails.root.join('files', @smartphone.device_id.to_s),
      Rails.root.join('public', 'uploads', @smartphone.device_id.to_s)
    ]

    device_dirs.each do |dir|
      FileUtils.rm_rf(dir) if Dir.exist?(dir.to_s)
    end
  rescue => e
    Rails.logger.warn("[ErasureService] File cleanup warning: #{e.message}")
  end

  def generate_erasure_certificate(report)
    certificate_data = {
      certificate_id: SecureRandom.uuid,
      type: 'GDPR_ERASURE_CERTIFICATE',
      device_id: @smartphone.device_id,
      device_name: @smartphone.name,
      erasure_started_at: report[:started_at]&.iso8601,
      erasure_completed_at: report[:completed_at]&.iso8601,
      data_categories_erased: report[:deleted].keys.map(&:to_s),
      total_records_erased: report[:total_deleted],
      erasure_method: 'database_deletion_with_file_removal',
      legal_basis: 'GDPR Article 17 - Right to Erasure',
      issued_at: Time.current.iso8601,
      checksum: nil
    }

    certificate_data[:checksum] = Digest::SHA256.hexdigest(certificate_data.except(:checksum).to_json)
    certificate_data
  end

  def audit_erasure(report)
    AuditService.log(
      action: 'delete',
      auditable: @smartphone,
      metadata: {
        gdpr_action: 'right_to_erasure',
        device_id: @smartphone.device_id,
        total_deleted: report[:total_deleted],
        data_categories: report[:deleted].keys.map(&:to_s),
        certificate_id: report[:certificate][:certificate_id]
      }
    )
  rescue => e
    Rails.logger.error("[ErasureService] Audit logging failed: #{e.message}")
  end
end
