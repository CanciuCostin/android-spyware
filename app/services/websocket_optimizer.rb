# frozen_string_literal: true

require 'zlib'
require 'json'

# Optimizes WebSocket communication through batching, compression,
# binary protocol for frequent messages, connection pooling, and
# adaptive heartbeat intervals.
class WebsocketOptimizer
  # Batching: group updates within this window (seconds)
  BATCH_WINDOW = 0.1
  # Compress payloads larger than this threshold (bytes)
  COMPRESSION_THRESHOLD = 1024
  # Maximum connections per IP
  MAX_CONNECTIONS_PER_IP = 10
  # Heartbeat interval bounds (seconds)
  HEARTBEAT_MIN_INTERVAL = 10
  HEARTBEAT_MAX_INTERVAL = 120
  HEARTBEAT_DEFAULT_INTERVAL = 30

  class << self
    # ── Message Batching ──────────────────────────────────────────────

    # Queue a message for batched delivery. Messages are grouped by
    # stream name and flushed after BATCH_WINDOW or when the batch
    # reaches +max_batch_size+.
    def enqueue(stream, message, priority: :normal, max_batch_size: 50)
      if priority == :high
        broadcast_now(stream, message)
        return
      end

      batch_key = "ws:batch:#{stream}"
      RedisPool.with do |redis|
        redis.rpush(batch_key, message.to_json)
        redis.expire(batch_key, 5) # TTL safety net
        queue_size = redis.llen(batch_key)

        if queue_size >= max_batch_size
          flush_batch(stream)
        else
          schedule_flush(stream) unless flush_scheduled?(stream)
        end
      end
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] Enqueue failed: #{e.message}"
      broadcast_now(stream, message)
    end

    # Flush all queued messages for a stream as a single batch broadcast.
    def flush_batch(stream)
      batch_key = "ws:batch:#{stream}"

      messages = RedisPool.with do |redis|
        items = redis.lrange(batch_key, 0, -1)
        redis.del(batch_key)
        redis.del("ws:batch_scheduled:#{stream}")
        items
      end

      return if messages.blank?

      parsed = messages.map { |m| JSON.parse(m) }
      payload = parsed.size == 1 ? parsed.first : { type: 'batch', messages: parsed }

      broadcast_now(stream, payload)
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] Flush failed for #{stream}: #{e.message}"
    end

    # ── Compression ───────────────────────────────────────────────────

    # Compress payload with gzip if it exceeds the threshold.
    # Returns a hash with encoding metadata so the client knows to decompress.
    def compress(payload)
      json = payload.is_a?(String) ? payload : payload.to_json
      return json if json.bytesize < COMPRESSION_THRESHOLD

      compressed = Zlib::Deflate.deflate(json, Zlib::BEST_SPEED)
      ratio = (compressed.bytesize.to_f / json.bytesize * 100).round(1)

      Rails.logger.debug "[WebsocketOptimizer] Compressed #{json.bytesize}B -> #{compressed.bytesize}B (#{ratio}%)"

      {
        _compressed: true,
        encoding: 'gzip',
        data: Base64.strict_encode64(compressed),
        original_size: json.bytesize
      }.to_json
    end

    # Decompress a previously compressed payload.
    def decompress(data)
      parsed = data.is_a?(String) ? JSON.parse(data) : data
      return parsed unless parsed.is_a?(Hash) && parsed['_compressed']

      raw = Base64.strict_decode64(parsed['data'])
      JSON.parse(Zlib::Inflate.inflate(raw))
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] Decompress failed: #{e.message}"
      parsed
    end

    # ── Binary Protocol ───────────────────────────────────────────────

    # Encode a frequent message type into a compact binary format.
    # Format: [1-byte type][payload]
    MESSAGE_TYPES = {
      'ping'             => 0x01,
      'pong'             => 0x02,
      'heartbeat'        => 0x03,
      'location_update'  => 0x04,
      'device_status'    => 0x05,
      'command_ack'      => 0x06
    }.freeze
    REVERSE_TYPES = MESSAGE_TYPES.invert.freeze

    def encode_binary(type, payload = {})
      type_byte = MESSAGE_TYPES[type.to_s]
      return nil unless type_byte

      json_payload = payload.to_json
      [type_byte].pack('C') + json_payload
    end

    def decode_binary(data)
      return nil if data.nil? || data.empty?

      type_byte = data[0].unpack1('C')
      type_name = REVERSE_TYPES[type_byte]
      return nil unless type_name

      payload = data.length > 1 ? JSON.parse(data[1..]) : {}
      { type: type_name, payload: payload }
    rescue JSON::ParserError
      nil
    end

    # ── Connection Pooling ────────────────────────────────────────────

    # Track and limit connections per IP address.
    def register_connection(ip, identifier)
      key = "ws:connections_ip:#{ip}"
      RedisPool.with do |redis|
        count = redis.scard(key)
        if count >= MAX_CONNECTIONS_PER_IP
          Rails.logger.warn "[WebsocketOptimizer] Connection limit reached for IP #{ip} (#{count})"
          return false
        end
        redis.sadd(key, identifier)
        redis.expire(key, 1.hour.to_i)
        true
      end
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] register_connection failed: #{e.message}"
      true # Fail open
    end

    def release_connection(ip, identifier)
      key = "ws:connections_ip:#{ip}"
      RedisPool.with do |redis|
        redis.srem(key, identifier)
      end
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] release_connection failed: #{e.message}"
    end

    def connections_for_ip(ip)
      RedisPool.with do |redis|
        redis.scard("ws:connections_ip:#{ip}")
      end
    rescue StandardError
      0
    end

    # ── Adaptive Heartbeat ────────────────────────────────────────────

    # Calculate heartbeat interval based on connection quality.
    # Devices with high latency or frequent reconnects get slower intervals
    # to reduce overhead; stable devices get faster intervals for
    # quicker disconnect detection.
    def adaptive_heartbeat_interval(device_id)
      info = ConnectionMonitor.connection_info(device_id)
      return HEARTBEAT_DEFAULT_INTERVAL unless info

      latency = info['latency'] || 0
      reconnects = info['reconnect_count'] || 0
      idle_time = info['idle_time'] || 0

      interval = HEARTBEAT_DEFAULT_INTERVAL

      # High latency → slower heartbeats to avoid false disconnects
      interval += 10 if latency > 500
      interval += 20 if latency > 1000

      # Frequent reconnects → slower heartbeats to reduce churn
      interval += (reconnects * 5).clamp(0, 30)

      # Very idle → slower heartbeats to save resources
      interval += 15 if idle_time > 120

      interval.clamp(HEARTBEAT_MIN_INTERVAL, HEARTBEAT_MAX_INTERVAL)
    rescue StandardError => e
      Rails.logger.error "[WebsocketOptimizer] adaptive_heartbeat failed: #{e.message}"
      HEARTBEAT_DEFAULT_INTERVAL
    end

    # ── Broadcast Helpers ─────────────────────────────────────────────

    # Broadcast with optional compression for large payloads.
    def smart_broadcast(stream, payload)
      json = payload.to_json
      if json.bytesize > COMPRESSION_THRESHOLD
        ActionCable.server.broadcast(stream, JSON.parse(compress(payload)))
      else
        ActionCable.server.broadcast(stream, payload)
      end
    end

    private

    def broadcast_now(stream, message)
      ActionCable.server.broadcast(stream, message)
    end

    def schedule_flush(stream)
      RedisPool.with do |redis|
        redis.set("ws:batch_scheduled:#{stream}", '1', ex: 1)
      end

      Thread.new do
        sleep(BATCH_WINDOW)
        flush_batch(stream)
      rescue StandardError => e
        Rails.logger.error "[WebsocketOptimizer] Scheduled flush error: #{e.message}"
      end
    end

    def flush_scheduled?(stream)
      RedisPool.with do |redis|
        redis.exists?("ws:batch_scheduled:#{stream}")
      end
    rescue StandardError
      false
    end
  end
end
