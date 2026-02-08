# frozen_string_literal: true

# Structured JSON logger with request/device context and PII redaction.
# Usage:
#   StructuredLogger.info("User logged in", device_id: "abc", request_id: "req-123")
#   StructuredLogger.error("Command failed", error: e, device_id: "abc")
class StructuredLogger
  PII_PATTERNS = {
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/ => '[EMAIL_REDACTED]',
    /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/ => '[PHONE_REDACTED]',
    /\b\d{3}-\d{2}-\d{4}\b/ => '[SSN_REDACTED]',
    /\b(?:\d[ -]*?){13,16}\b/ => '[CARD_REDACTED]',
    /password["\s:=]+\S+/i => 'password=[REDACTED]',
    /token["\s:=]+\S+/i => 'token=[REDACTED]',
    /secret["\s:=]+\S+/i => 'secret=[REDACTED]',
    /api_key["\s:=]+\S+/i => 'api_key=[REDACTED]'
  }.freeze

  LEVELS = %i[debug info warn error fatal].freeze

  class << self
    LEVELS.each do |level|
      define_method(level) do |message, context = {}|
        log(level, message, context)
      end
    end

    def log(level, message, context = {})
      entry = build_entry(level, message, context)
      json = entry.to_json

      case level
      when :debug then Rails.logger.debug(json)
      when :info  then Rails.logger.info(json)
      when :warn  then Rails.logger.warn(json)
      when :error then Rails.logger.error(json)
      when :fatal then Rails.logger.fatal(json)
      end

      # Track errors for ErrorTracker
      if %i[error fatal].include?(level)
        ErrorTracker.capture(message, context) if defined?(ErrorTracker)
      end

      entry
    end

    private

    def build_entry(level, message, context)
      entry = {
        timestamp: Time.current.iso8601(3),
        level: level.to_s.upcase,
        message: redact_pii(message.to_s),
        service: 'eaglespy',
        environment: Rails.env
      }

      entry[:request_id] = context.delete(:request_id) || current_request_id
      entry[:device_id] = context.delete(:device_id) if context[:device_id]

      if (error = context.delete(:error))
        entry[:error] = {
          class: error.class.name,
          message: redact_pii(error.message),
          backtrace: error.backtrace&.first(10)
        }
      end

      entry[:context] = redact_context(context) if context.any?
      entry
    end

    def redact_pii(text)
      return text unless text.is_a?(String)

      result = text.dup
      PII_PATTERNS.each { |pattern, replacement| result.gsub!(pattern, replacement) }
      result
    end

    def redact_context(ctx)
      ctx.transform_values do |v|
        v.is_a?(String) ? redact_pii(v) : v
      end
    end

    def current_request_id
      RequestStore.store[:request_id] if defined?(RequestStore)
    end
  end
end
