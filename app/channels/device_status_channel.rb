# frozen_string_literal: true

# Channel for live device status updates on the admin dashboard.
# Broadcasts online/offline transitions, battery level, and connection quality.
class DeviceStatusChannel < ApplicationCable::Channel
  DEVICE_STATUS_STREAM = 'device_status'

  def subscribed
    reject unless connection.current_user_type == :admin
    stream_from DEVICE_STATUS_STREAM

    # Send current state snapshot on subscribe
    transmit(type: 'snapshot', devices: current_device_statuses)
  end

  def unsubscribed
    stop_all_streams
  end

  # Admin requests a full refresh of device statuses
  def request_refresh
    transmit(type: 'snapshot', devices: current_device_statuses)
  end

  # Device reports its status (battery, signal, etc.)
  def report_status(data)
    device_id = data['device_id'].to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
    return if device_id.blank?

    status_data = {
      device_id: device_id,
      battery_level: data['battery_level'].to_i.clamp(0, 100),
      charging: !!data['charging'],
      signal_strength: data['signal_strength'].to_i.clamp(-120, 0),
      network_type: data['network_type'].to_s[0..20],
      timestamp: Time.current.iso8601
    }

    # Store in Redis for fast access
    DeviceStatusBroadcaster.update_device_metrics(device_id, status_data)

    # Broadcast to all admin subscribers
    ActionCable.server.broadcast(DEVICE_STATUS_STREAM, {
      type: 'device_update',
      device: status_data
    })
  end

  private

  def current_device_statuses
    statuses = DeviceStatusBroadcaster.all_device_statuses
    statuses.map do |status|
      if status.is_a?(Hash)
        timestamp = status['updated_at'] || status['last_metrics_at'] || status['timestamp']
        age = Time.current.to_i - timestamp.to_i rescue 300
        status.merge('stale' => age > 60)
      else
        status
      end
    end
  end
end
