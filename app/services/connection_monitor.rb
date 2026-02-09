# frozen_string_literal: true

# Tracks all active WebSocket connections, detects stale connections,
# and provides connection statistics.
# Uses Redis to share state across multiple Puma workers.
class ConnectionMonitor
  STALE_THRESHOLD = 5.minutes.to_i
  CLEANUP_BATCH_SIZE = 100

  # Register a new connection
  def self.register(device_id, connection_type: 'device', metadata: {})
    raise ArgumentError, "device_id is required" if device_id.blank?

    conn_data = {
      device_id: device_id,
      type: connection_type,
      connected_at: Time.current.to_i,
      last_activity: Time.current.to_i,
      reconnect_count: 0,
      metadata: metadata
    }

    RedisPool.with do |redis|
      redis.hset('ws:connections', device_id, conn_data.to_json)
      redis.sadd('ws:active_ids', device_id)
    end

    Rails.logger.info "[ConnectionMonitor] Registered: #{device_id} (#{connection_type})"
    true
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Register failed for #{device_id}: #{e.message}"
    false
  end

  # Unregister a connection
  def self.unregister(device_id)
    RedisPool.with do |redis|
      redis.hdel('ws:connections', device_id)
      redis.srem('ws:active_ids', device_id)
    end

    Rails.logger.info "[ConnectionMonitor] Unregistered: #{device_id}"
    true
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Unregister failed for #{device_id}: #{e.message}"
    false
  end

  # Record activity for a connection (keeps it from going stale)
  def self.touch(device_id)
    RedisPool.with do |redis|
      raw = redis.hget('ws:connections', device_id)
      return false unless raw

      conn = JSON.parse(raw)
      conn['last_activity'] = Time.current.to_i
      redis.hset('ws:connections', device_id, conn.to_json)
    end
    true
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Touch failed for #{device_id}: #{e.message}"
    false
  end

  # Record a reconnection event
  def self.record_reconnect(device_id)
    RedisPool.with do |redis|
      raw = redis.hget('ws:connections', device_id)
      return false unless raw

      conn = JSON.parse(raw)
      conn['reconnect_count'] = (conn['reconnect_count'] || 0) + 1
      conn['last_reconnect'] = Time.current.to_i
      conn['last_activity'] = Time.current.to_i
      redis.hset('ws:connections', device_id, conn.to_json)
    end
    true
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Record reconnect failed: #{e.message}"
    false
  end

  # Detect and clean up stale connections (no activity > threshold)
  def self.cleanup_stale_connections
    stale_ids = []
    current_time = Time.current.to_i

    RedisPool.with do |redis|
      all_connections = redis.hgetall('ws:connections')

      all_connections.each do |device_id, raw|
        conn = JSON.parse(raw)
        elapsed = current_time - (conn['last_activity'] || 0)

        if elapsed > STALE_THRESHOLD
          stale_ids << device_id
        end
      end

      # Remove stale connections in batches
      stale_ids.each_slice(CLEANUP_BATCH_SIZE) do |batch|
        batch.each do |device_id|
          redis.hdel('ws:connections', device_id)
          redis.srem('ws:active_ids', device_id)
        end
      end
    end

    if stale_ids.any?
      Rails.logger.info "[ConnectionMonitor] Cleaned up #{stale_ids.size} stale connections"
    end

    stale_ids
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Cleanup failed: #{e.message}"
    []
  end

  # Get connection info for a specific device
  def self.connection_info(device_id)
    RedisPool.with do |redis|
      raw = redis.hget('ws:connections', device_id)
      return nil unless raw

      conn = JSON.parse(raw)
      enrich_connection_data(conn)
    end
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Connection info failed for #{device_id}: #{e.message}"
    nil
  end

  # Get all active connections
  def self.all_connections
    RedisPool.with do |redis|
      connections = redis.hgetall('ws:connections')
      connections.map do |device_id, raw|
        conn = JSON.parse(raw)
        enrich_connection_data(conn)
      end
    end
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Failed to list connections: #{e.message}"
    []
  end

  # Aggregate statistics
  def self.statistics
    connections = all_connections
    now = Time.current.to_i

    total = connections.size
    return empty_stats if total == 0

    uptimes = connections.map { |c| now - (c['connected_at'] || now) }
    reconnects = connections.sum { |c| c['reconnect_count'] || 0 }
    latencies = connections.map { |c| c['latency'] }.compact

    {
      total_connections: total,
      device_connections: connections.count { |c| c['type'] == 'device' },
      admin_connections: connections.count { |c| c['type'] == 'admin' },
      average_uptime: (uptimes.sum.to_f / total).round,
      max_uptime: uptimes.max,
      total_reconnects: reconnects,
      average_reconnects: (reconnects.to_f / total).round(1),
      average_latency: latencies.any? ? (latencies.sum.to_f / latencies.size).round : nil,
      stale_count: connections.count { |c| (now - (c['last_activity'] || 0)) > STALE_THRESHOLD }
    }
  rescue StandardError => e
    Rails.logger.error "[ConnectionMonitor] Statistics failed: #{e.message}"
    empty_stats
  end

  private_class_method def self.enrich_connection_data(conn)
    now = Time.current.to_i
    conn['uptime'] = now - (conn['connected_at'] || now)
    conn['idle_time'] = now - (conn['last_activity'] || now)
    conn['stale'] = conn['idle_time'] > STALE_THRESHOLD
    conn
  end

  private_class_method def self.empty_stats
    {
      total_connections: 0,
      device_connections: 0,
      admin_connections: 0,
      average_uptime: 0,
      max_uptime: 0,
      total_reconnects: 0,
      average_reconnects: 0,
      average_latency: nil,
      stale_count: 0
    }
  end
end
