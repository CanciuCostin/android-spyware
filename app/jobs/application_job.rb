# frozen_string_literal: true

# Base class for all background jobs.
# Provides retry logic, error tracking, and structured logging.
class ApplicationJob < ActiveJob::Base
  # Automatically retry transient failures
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  retry_on Redis::BaseError, wait: 5.seconds, attempts: 3

  # Discard jobs whose records were deleted between enqueue and execution
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn "[#{job.class.name}] Discarded — record missing: #{error.message}"
  end

  around_perform do |job, block|
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info "[#{job.class.name}] started (queue=#{job.queue_name})"
    block.call
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3)
    Rails.logger.info "[#{job.class.name}] completed in #{elapsed}s"
    MetricsService.observe_histogram(:job_duration_seconds, elapsed, labels: { job: job.class.name })
  rescue StandardError => e
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3)
    Rails.logger.error "[#{job.class.name}] failed after #{elapsed}s: #{e.class} — #{e.message}"
    Rails.logger.error e.backtrace.first(15).join("\n")
    MetricsService.increment(:job_failures_total, labels: { job: job.class.name })
    raise
  end
end
