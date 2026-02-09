# frozen_string_literal: true

class ScheduledCommandExecutorJob < ApplicationJob
  queue_as :default

  # Run every minute via cron/sidekiq-cron/whenever
  def perform
    results = CommandSchedulerService.execute_due_commands

    if results.any?
      Rails.logger.info "[ScheduledCommandExecutorJob] Processed #{results.size} scheduled command(s)"

      # Broadcast execution summary to admin dashboard
      summary = {
        type: 'scheduled_commands_executed',
        count: results.size,
        succeeded: results.count { |r| r[:result].success? },
        failed: results.count { |r| r[:result].failure? },
        timestamp: Time.current.iso8601
      }

      ActionCable.server.broadcast('admin_devices', summary)
    end
  rescue StandardError => e
    Rails.logger.error "[ScheduledCommandExecutorJob] Fatal error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
