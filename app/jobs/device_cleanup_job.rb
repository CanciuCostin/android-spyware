# frozen_string_literal: true

# Periodic job that cleans up stale device connections and expired data.
# Intended to run every few minutes via Sidekiq scheduler or cron.
#
# Usage:
#   DeviceCleanupJob.perform_later
#   DeviceCleanupJob.set(wait: 5.minutes).perform_later
class DeviceCleanupJob < ApplicationJob
  queue_as :scheduled

  STALE_COMMAND_AGE = 24.hours
  EXPIRED_UPLOAD_AGE = 6.hours

  def perform
    results = {
      stale_connections: cleanup_stale_connections,
      stale_heartbeats: cleanup_stale_heartbeats,
      timed_out_commands: timeout_stale_commands,
      expired_uploads: cleanup_expired_uploads
    }

    Rails.logger.info "[DeviceCleanupJob] Summary: #{results.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    MetricsService.set_gauge(:device_cleanup_last_run, Time.current.to_i)
    results
  end

  private

  def cleanup_stale_connections
    ConnectionMonitor.cleanup_stale_connections.size
  rescue StandardError => e
    Rails.logger.error "[DeviceCleanupJob] Connection cleanup failed: #{e.message}"
    0
  end

  def cleanup_stale_heartbeats
    HeartbeatMonitor.cleanup_stale_heartbeats
  rescue StandardError => e
    Rails.logger.error "[DeviceCleanupJob] Heartbeat cleanup failed: #{e.message}"
    0
  end

  def timeout_stale_commands
    stale = PendingCommand.where(status: [:pending, :processing])
                          .where('created_at < ?', STALE_COMMAND_AGE.ago)
    count = stale.count
    stale.update_all(status: :timeout, completed_at: Time.current) if count > 0
    count
  rescue StandardError => e
    Rails.logger.error "[DeviceCleanupJob] Command timeout failed: #{e.message}"
    0
  end

  def cleanup_expired_uploads
    expired = ResumableUpload.where('created_at < ?', EXPIRED_UPLOAD_AGE.ago) rescue nil
    return 0 unless expired

    count = expired.count
    expired.destroy_all if count > 0
    count
  rescue StandardError => e
    Rails.logger.error "[DeviceCleanupJob] Upload cleanup failed: #{e.message}"
    0
  end
end
