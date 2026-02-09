# frozen_string_literal: true

begin
  require_relative '../../lib/spyware_tracing'
  require_relative '../../lib/msf_instrumentation'

  # Initialize OpenTelemetry tracing
  environment = Rails.env
  SpywareTracing.initialize_tracing(environment: environment)

  Rails.logger.info("🔍 OpenTelemetry tracing initialized for #{environment} environment")
  Rails.logger.info("📊 Jaeger collector configured at #{ENV.fetch('JAEGER_HOST', 'localhost')}:#{ENV.fetch('JAEGER_PORT', 6831)}")

  # Configure Rack middleware for automatic span creation
  # Rails.application.middleware.use OpenTelemetry::Instrumentation::Rack::Middlewares::RequestHandler
  # Auto-instrumentation via c.use 'OpenTelemetry::Instrumentation::Rack' handles this now.

  # Add custom tracing for critical operations
  ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_name, started, finished, _unique_id, data|
    duration = finished - started
    
    controller = data[:controller]
    action = data[:action]
    status = data[:status]
    
    if SpywareTracing.tracer
      SpywareTracing.tracer.in_span(
        "controller.#{controller}.#{action}",
        attributes: {
          'http.status_code' => status || 0,
          'http.method' => data[:method],
          'http.url' => data[:path],
          'duration.ms' => (duration * 1000).round(2)
        }
      ) do |span|
        # Add errors if applicable (guard against nil status)
        span.set_attribute('error', true) if status && status >= 400
      end
    end
  end
rescue LoadError, NameError => e
  Rails.logger.warn("⚠️ OpenTelemetry/Tracing could not be initialized: #{e.message}")
end
