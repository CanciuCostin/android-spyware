# Concern mixed into controllers that need to dispatch commands to Android devices.
#
# Async command flow:
#   1. send_command_async creates a PendingCommand record (status: pending).
#   2. The command is broadcast via ActionCable to "commands_<device_id>".
#   3. The Android client receives the command, executes it, and sends a response
#      back through CommandChannel, which is picked up by ResponseProcessor.
#   4. ResponseProcessor marks the PendingCommand as completed/failed.
#
# Synchronous convenience:
#   send_command_and_wait combines send + a blocking poll loop that reloads the
#   PendingCommand from the database every 0.5 s until it reaches a terminal
#   state or times out. This is suitable for short-lived commands (< 30 s) but
#   will block the controller thread — do not use for long-running operations.
module CommandSender
  extend ActiveSupport::Concern
  
  # Single source of truth: CommandValidator.ALLOWED_COMMANDS
  ALLOWED_COMMANDS = CommandValidator::ALLOWED_COMMANDS
  
  def send_command_async(smartphone, command, params = {})
    request_id = SecureRandom.uuid
    device_id = smartphone.device_id
    
    raise "Device ID not set for smartphone #{smartphone.id}" unless device_id
    
    # SECURITY: Validate command is in whitelist
    unless ALLOWED_COMMANDS.include?(command.to_s)
      raise ArgumentError, "Invalid command: #{command}. Allowed commands: #{ALLOWED_COMMANDS.join(', ')}"
    end
    
    # SECURITY: Sanitize parameters based on command type
    sanitized_params = sanitize_command_params(command, params)

    priority = CommandValidator.priority_for(command)
    resource = CommandValidator.resource_for(command)
    
    # Create pending command record
    pending_command = PendingCommand.create!(
      smartphone: smartphone,
      request_id: request_id,
      command: command,
      params: sanitized_params,
      status: :pending
    )
    
        # Broadcast command to device via ActionCable
        # Channel stream name must match CommandChannel#subscribed: "commands_#{device_id}"        
        ActionCable.server.broadcast(
          "commands_#{device_id}",
          {
            request_id: request_id,
            action: command.to_s,
            params: sanitized_params,
            priority: priority,
            resource: resource
          }
        )
        Rails.logger.info("Sent command #{command} (#{priority}/#{resource}) to device #{device_id}, request_id: #{request_id}")
    
    pending_command
  end
  
  # Blocking poll loop. We use DB polling (reload) instead of ActionCable
  # subscription because controllers need a synchronous return value and
  # ActionCable callbacks execute on a different thread/connection.
  def wait_for_response(pending_command, timeout: 30.seconds)
    start_time = Time.current
    
    loop do
      pending_command.reload
      
      if pending_command.completed? || pending_command.failed? || pending_command.timeout?
        return pending_command
      end
      
      if Time.current - start_time > timeout
        pending_command.mark_failed("Timeout waiting for response")
        return pending_command
      end
      
      sleep 0.5
    end
  end
  
  def send_command_and_wait(smartphone, command, params = {}, timeout: 30.seconds)
    pending_command = send_command_async(smartphone, command, params)
    wait_for_response(pending_command, timeout: timeout)
  end
  
  private
  
  # SECURITY: Sanitize command parameters based on command type
  def sanitize_command_params(command, params)
    case command.to_s
    when 'send_sms'
      {
        phone_number: sanitize_phone_number(params[:phone_number]),
        message_body: sanitize_text(params[:message_body])
      }
    when 'uninstall_app', 'launch_app'
      {
        package_name: sanitize_package_name(params[:package_name])
      }
    when 'install_apk'
      {
        apk_path: params[:apk_path].present? ? sanitize_url_or_path(params[:apk_path]) : nil,
        apk_base64: params[:apk_base64].present? ? params[:apk_base64].to_s.gsub(/[^a-zA-Z0-9+\/=\s]/, '') : nil
      }.compact
    when 'start_camera'
      {
        camera_id: params[:camera_id].to_s.gsub(/[^0-9]/, '')[0..1] # Only digits, max 2 chars
      }
    when 'set_audio_mode'
      # Whitelist audio modes
      mode = params[:mode].to_s
      {
        mode: %w[normal vibrate silent].include?(mode) ? mode : 'normal'
      }
    else
      # For other commands, allow params but sanitize strings
      params.transform_values do |value|
        value.is_a?(String) ? sanitize_text(value) : value
      end
    end
  end
  
  # Sanitize phone number (digits, +, -, (), spaces only)
  def sanitize_phone_number(number)
    number.to_s.gsub(/[^0-9+\-() ]/, '')[0..20]
  end
  
  # Sanitize general text (strip and limit length)
  def sanitize_text(text)
    text.to_s.strip[0..1000]
  end
  
  # Sanitize Android package name (alphanumeric, dots, underscores)
  def sanitize_package_name(name)
    name.to_s.gsub(/[^a-zA-Z0-9._]/, '')[0..255]
  end
  
  # Sanitize URL or file path
  def sanitize_url_or_path(path)
    # Allow URLs (http/https) or absolute paths, but sanitize
    path_str = path.to_s.strip[0..500]
    
    # If it's a URL, validate basic structure
    if path_str =~ /\Ahttps?:\/\//
      # Basic URL validation (don't allow javascript:, data:, etc.)
      path_str if path_str =~ /\Ahttps?:\/\/[a-zA-Z0-9.\-_\/:%?=&]+\z/
    else
      # For file paths, sanitize
      path_str.gsub(/[^a-zA-Z0-9.\-_\/]/, '')
    end
  end
end
