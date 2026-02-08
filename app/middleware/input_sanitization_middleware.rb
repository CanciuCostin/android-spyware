# frozen_string_literal: true

# Rack middleware for global request parameter sanitization.
# Removes null bytes, normalizes unicode, and encodes HTML entities
# in all request parameters before they reach the application.
class InputSanitizationMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    sanitize_query_string(env)
    sanitize_form_data(env, request)

    @app.call(env)
  rescue => e
    Rails.logger.error("[InputSanitizationMiddleware] Error: #{e.message}")
    @app.call(env)
  end

  private

  def sanitize_query_string(env)
    return unless env['QUERY_STRING'].is_a?(String) && env['QUERY_STRING'].present?

    env['QUERY_STRING'] = sanitize_value(env['QUERY_STRING'])
  end

  def sanitize_form_data(env, request)
    return unless request.post? || request.put? || request.patch?
    return unless env['rack.input']

    content_type = env['CONTENT_TYPE'].to_s
    return unless content_type.include?('application/x-www-form-urlencoded')

    body = env['rack.input'].read
    env['rack.input'].rewind

    sanitized_body = sanitize_value(body)

    if sanitized_body != body
      env['rack.input'] = StringIO.new(sanitized_body)
      env['CONTENT_LENGTH'] = sanitized_body.bytesize.to_s
    end
  end

  def sanitize_value(value)
    return value unless value.is_a?(String)

    sanitized = value.dup

    # Remove null bytes
    sanitized.gsub!("\x00", '')
    sanitized.gsub!('%00', '')

    # Unicode normalization (NFC)
    sanitized = sanitized.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    sanitized = sanitized.unicode_normalize(:nfc) if sanitized.respond_to?(:unicode_normalize)

    sanitized
  end
end
