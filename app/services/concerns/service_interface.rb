# frozen_string_literal: true

# Common interface for all services.
# Provides .call class method, Result object pattern, logging, and metrics.
#
# Usage:
#   class MyService
#     include ServiceInterface
#
#     def call
#       # business logic
#       success(value)
#     end
#   end
#
#   result = MyService.call(arg1, arg2)
#   result.success? # => true
#   result.value     # => whatever was returned
module ServiceInterface
  extend ActiveSupport::Concern

  class_methods do
    # Entry point — instantiates the service and runs #call,
    # wrapping unexpected errors in a Result.failure.
    def call(*args, **kwargs, &block)
      instance = new(*args, **kwargs, &block)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = instance.call

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      track_metrics(name, result, elapsed)

      result
    rescue StandardError => e
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      log_error(e)
      track_metrics(name, nil, elapsed, error: e)
      Result.failure(e.message)
    end

    private

    def log_error(error)
      if defined?(StructuredLogger)
        StructuredLogger.error("#{name} failed", error: error)
      else
        Rails.logger.error("#{name} failed: #{error.message}")
      end
    end

    def track_metrics(service_name, result, elapsed, error: nil)
      return unless defined?(MetricsService)

      metric_name = service_name.underscore.tr('/', '_')
      status = if error
                 'error'
               elsif result.respond_to?(:success?) && result.success?
                 'success'
               else
                 'failure'
               end

      MetricsService.increment("service_calls_total", labels: { service: metric_name, status: status })
      MetricsService.observe_histogram("service_duration_seconds", elapsed, labels: { service: metric_name })
    end
  end

  # Convenience helpers available to service instances

  def success(value = nil)
    Result.success(value)
  end

  def failure(error)
    Result.failure(error)
  end
end
