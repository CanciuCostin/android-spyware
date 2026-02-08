# frozen_string_literal: true

# Service for broadcasting device status changes to the admin dashboard.
# Uses Redis to aggregate updates and debounce rapid state changes.
class DeviceStatusBroadcaster
  REDIS_KEY_PREFIX = 'device_status:'
  DEBOUNCE_SECONDS = 2
  STATUS_TTL = 10.minutes.to_i

  # Broadcast a device coming online
  def self.device_online(device_id, metadata: {})
    status = {
      device_id: device_id,
      online: true,
      connected_at: Time.current.iso8601,
      metadata: metadata
    }

    store_status(device_id, status)
    debounced_broadcast(device_id, type: 'device_online', device: status)
  end

  # Broadcast a device going offline
  def self.device_offline(device_id)
    status = load_status(device_id) || {}
    status.merge!(
      online: false,
      disconnected_at: Time.current.iso8601
    )

    store_status(device_id, status)
    debounced_broadcast(device_id, type: 'device_offline', device: status)
  end

  # Update device metrics (battery, signal, etc.)
  def self.update_device_metrics(device_id, metrics)
    status = load_status(device_id) || { device_id: device_id, online: true }
    status.merge!(metrics.stringify_keys)
    status['last_metrics_at'] = Time.current.iso8601

    store_status(device_id, status)
  end

  # Broadcast battery level change
  def self.battery_update(device_id, level:, charging: false)
    update_device_metrics(device_id, {
      battery_level: level.to_i.clamp(0, 100),
      charging: charging
    })

    debounced_broadcast(device_id, {
      type: 'battery_update',
      device_id: device_id,
      battery_level: level,
      charging: charging
    })
  end

  # Get all device statuses from Redis
  def self.all_device_statuses
    devices = []
    RedisPool.with do |redis|
      keys = redis.keys("#{REDIS_KEY_PREFIX}*")
      return devices if keys.empty?

      redis.mget(*keys).each do |raw|
        next unless raw
        devices << JSON.parse(raw)
      rescue JSON::ParserError
        next
      end
    end
    devices
  rescue StandardError => e
    Rails.logger.error "[DeviceStatusBroadcaster] Failed to load statuses: #{e.message}"
    []
  end

  # Get status for a specific device
  def self.device_status(device_id)
    load_status(device_id)
  end

  # Build a full dashboard snapshot including DB data
  def self.dashboard_snapshot
    smartphones = Smartphone.includes(:apk_installation).limit(100)
    online_ids = online_device_ids

    smartphones.map do |device|
      cached = load_status(device.device_id) || {}
      {
        id: device.id,
        device_id: device.device_id,
        name: device.name,
        os: device.operating_system,
        online: online_ids.include?(device.device_id),
        battery_level: cached['battery_level'],
        charging: cached['charging'],
        signal_strength: cached['signal_strength'],
        network_type: cached['network_type'],
        last_seen: cached['last_metrics_at'] || device.updated_at&.iso8601
      }
    end
  end

  private

  def self.store_status(device_id, status)
    RedisPool.with do |redis|
      redis.setex("#{REDIS_KEY_PREFIX}#{device_id}", STATUS_TTL, status.to_json)
    end
  rescue StandardError => e
    Rails.logger.error "[DeviceStatusBroadcaster] Store failed for #{device_id}: #{e.message}"
  end

  def self.load_status(device_id)
    RedisPool.with do |redis|
      raw = redis.get("#{REDIS_KEY_PREFIX}#{device_id}")
      return nil unless raw
      JSON.parse(raw)
    end
  rescue StandardError => e
    Rails.logger.error "[DeviceStatusBroadcaster] Load failed for #{device_id}: #{e.message}"
    nil
  end

  def self.online_device_ids
    RedisPool.with { |redis| redis.smembers('online_devices') }
  rescue StandardError
    []
  end

  # Debounce broadcasts to avoid flooding the WebSocket
  def self.debounced_broadcast(device_id, payload)
    debounce_key = "device_broadcast_debounce:#{device_id}"

    RedisPool.with do |redis|
      # Only broadcast if debounce window has passed
      return unless redis.set(debounce_key, '1', ex: DEBOUNCE_SECONDS, nx: true)
    end

    ActionCable.server.broadcast(DeviceStatusChannel::DEVICE_STATUS_STREAM, payload)
  rescue StandardError => e
    Rails.logger.error "[DeviceStatusBroadcaster] Broadcast failed: #{e.message}"
    # Fallback: broadcast without debounce
    ActionCable.server.broadcast(DeviceStatusChannel::DEVICE_STATUS_STREAM, payload) rescue nil
  end
end
