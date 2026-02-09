# frozen_string_literal: true

module DeviceStatusHelper
  # Check if a device is currently online based on heartbeat
  def device_online?(device_id)
    HeartbeatMonitor.is_online?(device_id)
  end

  # Check if a smartphone is currently online
  def smartphone_online?(smartphone)
    HeartbeatMonitor.is_online?(smartphone.device_id)
  end

  # Get last seen time for a device
  def device_last_seen(device_id)
    HeartbeatMonitor.get_last_seen(device_id)
  end

  # Get formatted status badge for device
  def device_status_badge(device_id)
    if HeartbeatMonitor.is_online?(device_id)
      content_tag(:span, '🟢 Online', class: 'status_badge status_online')
    else
      content_tag(:span, '🔴 Offline', class: 'status_badge status_offline')
    end
  end

  # Get status for a smartphone with last seen time
  def smartphone_status_with_time(smartphone)
    if HeartbeatMonitor.is_online?(smartphone.device_id)
      content_tag(:div, class: 'device_status') do
        concat(content_tag(:span, '🟢 Online', class: 'status_online'))
        concat(' - ')
        concat(content_tag(:span, 'Last seen just now', class: 'last_seen'))
      end
    else
      last_seen = HeartbeatMonitor.get_last_seen(smartphone.device_id)
      if last_seen
        time_ago = distance_of_time_in_words(last_seen, Time.current, true)
        content_tag(:div, class: 'device_status') do
          concat(content_tag(:span, '🔴 Offline', class: 'status_offline'))
          concat(' - ')
          concat(content_tag(:span, "Last seen #{time_ago} ago", class: 'last_seen'))
        end
      else
        content_tag(:span, '🔴 Never Connected', class: 'status_offline')
      end
    end
  end

  # Get human-readable time since last seen
  def time_since_last_seen(device_id)
    last_seen = HeartbeatMonitor.get_last_seen(device_id)
    return 'Never' if last_seen.blank?
    
    elapsed_seconds = (Time.current - last_seen).to_i
    format_time_elapsed(elapsed_seconds)
  end

  # Get all online devices count
  def online_devices_count
    HeartbeatMonitor.get_all_online_devices.count
  end

  # Get list of online devices
  def online_devices_list
    HeartbeatMonitor.get_all_online_devices
  end

  private

  def format_time_elapsed(seconds)
    case seconds
    when 0..59
      "#{seconds}s"
    when 60...3600
      "#{(seconds / 60).to_i}m"
    when 3600...86400
      "#{(seconds / 3600).to_i}h"
    else
      "#{(seconds / 86400).to_i}d"
    end
  end
end
