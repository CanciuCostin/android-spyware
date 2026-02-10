# frozen_string_literal: true

# Server-side heartbeat channel. Sends periodic pings to clients
# and disconnects on missed pongs.
class HeartbeatChannel < ApplicationCable::Channel
  PING_INTERVAL = 30.seconds
  MAX_MISSED_PONGS = 3

  periodically :send_ping, every: PING_INTERVAL

  def subscribed
    @device_id = params[:device_id].to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
    @missed_pongs = Concurrent::AtomicFixnum.new(0)

    stream_from "heartbeat_#{@device_id}"

    ConnectionMonitor.register(@device_id, connection_type: current_user_type.to_s)
    Rails.logger.info "[HeartbeatChannel] #{@device_id} subscribed"
  end

  def unsubscribed
    ConnectionMonitor.unregister(@device_id)
    Rails.logger.info "[HeartbeatChannel] #{@device_id} unsubscribed"
  end

  # Client responds to ping with pong
  def pong(data)
    @missed_pongs.value = 0
    ConnectionMonitor.touch(@device_id)

    # Calculate latency if ping timestamp is present
    if data['ping_sent_at'].present?
      latency = ((Time.current.to_f * 1000) - data['ping_sent_at'].to_f).round
      Rails.logger.debug "[HeartbeatChannel] #{@device_id} pong (latency: #{latency}ms)"
    end
  end

  # Client-initiated ping (alternative flow)
  def ping(data)
    transmit(
      type: 'pong',
      ping_sent_at: data['sent_at'],
      server_time: (Time.current.to_f * 1000).to_i
    )
    ConnectionMonitor.touch(@device_id)
  end

  private

  def send_ping
    missed = @missed_pongs.increment

    if missed > MAX_MISSED_PONGS
      Rails.logger.warn "[HeartbeatChannel] #{@device_id}: #{missed} missed pongs, disconnecting"
      ConnectionMonitor.unregister(@device_id)
      stop_all_streams
      connection.close
      return
    end

    transmit(
      type: 'ping',
      sent_at: (Time.current.to_f * 1000).to_i,
      missed_pongs: missed - 1 # -1 because we just incremented
    )
  end
end
