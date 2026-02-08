# frozen_string_literal: true

# Manages device heartbeat signals to track online/offline status
# Stores last seen timestamp in Redis for real-time device status monitoring
class HeartbeatMonitor
  HEARTBEAT_TTL = 5.minutes.to_i # Devices considered offline after 5 minutes without heartbeat

  # Process incoming heartbeat from device
  # Updates Redis with current timestamp
  def self.process_heartbeat(device_id, metadata = {})
    raise ArgumentError, "device_id cannot be blank" if device_id.blank?

    RedisPool.with do |redis|
      # Update last seen timestamp
      heartbeat_key = "last_seen_#{device_id}"
      redis.set(heartbeat_key, Time.current.to_i, ex: HEARTBEAT_TTL * 2)

      # Mark device as online
      redis.sadd('online_devices', device_id)

      # Store device metadata if provided
      if metadata.present?
        metadata_key = "device_metadata_#{device_id}"
        redis.set(metadata_key, metadata.to_json, ex: HEARTBEAT_TTL * 2)
      end

      Rails.logger.debug "[HeartbeatMonitor] Heartbeat received for device: #{device_id}"
      true
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error processing heartbeat for #{device_id}: #{e.message}"
    false
  end

  # Get last seen time for a device
  def self.get_last_seen(device_id)
    RedisPool.with do |redis|
      timestamp = redis.get("last_seen_#{device_id}")
      return nil if timestamp.blank?
      Time.at(timestamp.to_i)
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error getting last seen for #{device_id}: #{e.message}"
    nil
  end

  # Check if device is currently online
  def self.is_online?(device_id)
    RedisPool.with do |redis|
      redis.sismember('online_devices', device_id)
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error checking if device #{device_id} is online: #{e.message}"
    false
  end

  # Get all online devices
  def self.get_all_online_devices
    RedisPool.with do |redis|
      redis.smembers('online_devices')
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error getting online devices: #{e.message}"
    []
  end

  # Mark device as offline
  def self.mark_offline(device_id)
    RedisPool.with do |redis|
      redis.srem('online_devices', device_id)
      redis.del("last_seen_#{device_id}")
      redis.del("device_metadata_#{device_id}")
      Rails.logger.debug "[HeartbeatMonitor] Device marked offline: #{device_id}"
      true
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error marking device #{device_id} as offline: #{e.message}"
    false
  end

  # Get device metadata (last known state)
  def self.get_device_metadata(device_id)
    RedisPool.with do |redis|
      metadata_json = redis.get("device_metadata_#{device_id}")
      return {} if metadata_json.blank?
      JSON.parse(metadata_json)
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error getting metadata for #{device_id}: #{e.message}"
    {}
  end

  # Clean up stale heartbeats (called by background job)
  def self.cleanup_stale_heartbeats
    RedisPool.with do |redis|
      online_devices = redis.smembers('online_devices')
      current_time = Time.current.to_i

      stale_count = 0
      online_devices.each do |device_id|
        last_seen_timestamp = redis.get("last_seen_#{device_id}")
        next if last_seen_timestamp.blank?

        elapsed = current_time - last_seen_timestamp.to_i
        if elapsed > HEARTBEAT_TTL
          mark_offline(device_id)
          stale_count += 1
        end
      end

      Rails.logger.info "[HeartbeatMonitor] Cleaned up #{stale_count} stale heartbeats"
      stale_count
    end
  rescue StandardError => e
    Rails.logger.error "[HeartbeatMonitor] Error cleaning up stale heartbeats: #{e.message}"
    0
  end
end
