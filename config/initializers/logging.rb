# frozen_string_literal: true

# Configure structured JSON logging with request_id tracking and log rotation.
# Loaded after Rails framework initialization.

# JSON log formatter for Rails logger
class JsonLogFormatter < Logger::Formatter
  def call(severity, timestamp, _progname, msg)
    entry = {
      timestamp: timestamp.utc.iso8601(3),
      level: severity,
      pid: Process.pid
    }

    # Attach request_id if available
    if defined?(RequestStore) && RequestStore.store[:request_id]
      entry[:request_id] = RequestStore.store[:request_id]
    end

    # Parse existing JSON messages (from StructuredLogger) or wrap plain text
    if msg.is_a?(String) && msg.start_with?('{')
      begin
        parsed = JSON.parse(msg)
        entry.merge!(parsed)
      rescue JSON::ParserError
        entry[:message] = msg
      end
    else
      entry[:message] = msg.to_s
    end

    entry.to_json + "\n"
  end
end

# Apply JSON formatter in non-development environments
unless Rails.env.development?
  Rails.logger.formatter = JsonLogFormatter.new
end

# Log rotation: daily, keep 30 files (production only, when using file logger)
if Rails.env.production? && !ENV['RAILS_LOG_TO_STDOUT']
  log_path = Rails.root.join('log', "#{Rails.env}.log")
  rotated_logger = ActiveSupport::Logger.new(log_path, 30, 'daily')
  rotated_logger.formatter = JsonLogFormatter.new
  Rails.logger = ActiveSupport::TaggedLogging.new(rotated_logger)
end

# Inject request_id into RequestStore for every request
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_name, _started, _finished, _id, data|
  if defined?(RequestStore)
    RequestStore.store[:request_id] ||= data[:headers]&.env&.dig('action_dispatch.request_id')
  end
end

Rails.logger.info('📋 Structured logging initialized')
