# frozen_string_literal: true

# Sentry-compatible error tracking configuration.
# Set SENTRY_DSN in environment to enable external reporting.
Rails.application.config.after_initialize do
  ErrorTracking.configure
end

module ErrorTracking
  SCRUBBED_FIELDS = %w[
    password password_confirmation token api_key secret
    authorization cookie session_id credit_card ssn
  ].freeze

  class << self
    def configure
      @config = Configuration.new
      yield @config if block_given?

      setup_exception_handler
      Rails.logger.info("[ErrorTracking] Initialized (env=#{@config.environment}, release=#{@config.release})")
    end

    def config
      @config ||= Configuration.new
    end

    def capture_exception(exception, context = {})
      sanitized = scrub_pii(context)
      enriched = sanitized.merge(
        environment: config.environment,
        release: config.release,
        server_name: config.server_name,
        timestamp: Time.current.iso8601
      )

      # Persist to database via ErrorAggregator
      ErrorAggregator.track(exception, enriched) if defined?(ErrorAggregator)

      # Forward to in-memory tracker
      ErrorTracker.capture(exception.message, error: exception, **enriched) if defined?(ErrorTracker)

      add_breadcrumb('exception', exception.class.name, exception.message)
    rescue => e
      Rails.logger.error("[ErrorTracking] Failed to capture exception: #{e.message}")
    end

    def add_breadcrumb(category, message, data = nil)
      breadcrumbs.push({
        category: category,
        message: message.to_s.truncate(200),
        data: data,
        timestamp: Time.current.iso8601
      })
      breadcrumbs.shift if breadcrumbs.size > config.max_breadcrumbs
    end

    def breadcrumbs
      Thread.current[:error_tracking_breadcrumbs] ||= []
    end

    private

    def setup_exception_handler
      return unless Rails.env.production? || Rails.env.staging?

      Rails.application.config.exceptions_app = lambda do |env|
        exception = env['action_dispatch.exception']
        capture_exception(exception, request_env: env) if exception
        ApplicationController.action(:render_error).call(env)
      rescue => e
        Rails.logger.error("[ErrorTracking] Exception handler error: #{e.message}")
        [500, { 'Content-Type' => 'text/plain' }, ['Internal Server Error']]
      end
    end

    def scrub_pii(context)
      return context unless context.is_a?(Hash)

      context.each_with_object({}) do |(key, value), result|
        if SCRUBBED_FIELDS.any? { |field| key.to_s.downcase.include?(field) }
          result[key] = '[FILTERED]'
        elsif value.is_a?(Hash)
          result[key] = scrub_pii(value)
        else
          result[key] = value
        end
      end
    end
  end

  class Configuration
    attr_accessor :dsn, :environment, :release, :server_name,
                  :max_breadcrumbs, :send_default_pii,
                  :excluded_exceptions

    def initialize
      @dsn = ENV['SENTRY_DSN']
      @environment = ENV.fetch('RAILS_ENV', 'development')
      @release = ENV.fetch('APP_RELEASE', "eaglespy@#{read_version}")
      @server_name = ENV.fetch('HOSTNAME', Socket.gethostname)
      @max_breadcrumbs = 50
      @send_default_pii = false
      @excluded_exceptions = %w[
        ActionController::RoutingError
        ActiveRecord::RecordNotFound
        ActionController::InvalidAuthenticityToken
      ]
    end

    def enabled?
      dsn.present?
    end

    private

    def read_version
      version_file = Rails.root.join('VERSION')
      File.exist?(version_file) ? File.read(version_file).strip : '5.0.0'
    rescue
      '5.0.0'
    end
  end
end
