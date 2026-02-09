# frozen_string_literal: true

# Centralized input validation service that delegates to specialized validators.
# Usage:
#   result = InputValidator.validate_device_id("abc-123")
#   result.valid? # => true/false
#   result.value   # => sanitized value
#   result.error   # => error message
class InputValidator < ApplicationService
  class ValidationError < StandardError; end

  class << self
    # --- Device ID ---
    def validate_device_id(device_id)
      DeviceIdValidator.validate(device_id)
    end

    def sanitize_device_id(device_id)
      DeviceIdValidator.sanitize(device_id)
    end

    # --- Upload ID ---
    def validate_upload_id(upload_id)
      UploadValidator.validate_upload_id(upload_id)
    end

    # --- Commands ---
    def validate_command(command, params = {})
      CommandValidator.validate(command, params)
    end

    def command_allowed?(command)
      CommandValidator.allowed?(command)
    end

    # --- File Paths ---
    def validate_file_path(path, base_dir: nil)
      FilePathValidator.validate(path, base_dir: base_dir)
    end

    def sanitize_file_path(path)
      FilePathValidator.sanitize(path)
    end

    # --- Uploads ---
    def validate_upload(params)
      UploadValidator.validate(params)
    end

    # --- Coordinates ---
    def validate_coordinates(lat, lng)
      CoordinateValidator.validate(lat, lng)
    end

    # --- Phone Numbers ---
    def validate_phone_number(number)
      PhoneNumberValidator.validate(number)
    end

    def sanitize_phone_number(number)
      PhoneNumberValidator.sanitize(number)
    end

    # --- SQL Injection Prevention ---
    def sanitize_sql_input(value)
      return '' if value.nil?

      str = value.to_s
      # Remove or escape dangerous SQL characters
      str = str.gsub(/['";\\]/, '')
      str = str.gsub(/--/, '')
      str = str.gsub(/\/\*.*?\*\//m, '')
      str.strip
    end

    def contains_sql_injection?(value)
      return false if value.nil?

      str = value.to_s.downcase
      sql_patterns = [
        /(\b(union|select|insert|update|delete|drop|alter|create|exec|execute)\b\s)/i,
        /(\b(or|and)\b\s+\d+\s*=\s*\d+)/i,
        /(--|#|\/\*)/,
        /(\bwaitfor\b\s+\bdelay\b)/i,
        /(\bsleep\s*\()/i,
        /(\bbenchmark\s*\()/i,
        /(';|";|`)/
      ]

      sql_patterns.any? { |p| str.match?(p) }
    end

    # --- XSS Sanitization ---
    def sanitize_xss(value)
      return '' if value.nil?

      str = value.to_s
      str = str.gsub(/&/, '&amp;')
      str = str.gsub(/</, '&lt;')
      str = str.gsub(/>/, '&gt;')
      str = str.gsub(/"/, '&quot;')
      str = str.gsub(/'/, '&#x27;')
      str = str.gsub(/\//, '&#x2F;')
      str
    end

    def contains_xss?(value)
      return false if value.nil?

      str = value.to_s
      xss_patterns = [
        /<\s*script/i,
        /javascript\s*:/i,
        /on\w+\s*=/i,
        /data\s*:\s*text\/html/i,
        /vbscript\s*:/i,
        /<\s*iframe/i,
        /<\s*object/i,
        /<\s*embed/i,
        /<\s*svg\s/i,
        /expression\s*\(/i
      ]

      xss_patterns.any? { |p| str.match?(p) }
    end

    # --- Rate Limiting Helpers ---
    def rate_limit_key(input_type, identifier)
      "input_validation:rate_limit:#{input_type}:#{identifier}"
    end

    def within_rate_limit?(input_type, identifier, max_requests: 100, window: 60)
      return true unless defined?(Rails) && Rails.cache

      key = rate_limit_key(input_type, identifier)
      count = Rails.cache.read(key).to_i

      if count >= max_requests
        false
      else
        Rails.cache.write(key, count + 1, expires_in: window.seconds) if count.zero?
        Rails.cache.increment(key) if count.positive?
        true
      end
    end

    # --- General Sanitization ---
    def sanitize_string(value, max_length: 1000)
      return '' if value.nil?

      value.to_s.strip[0, max_length]
    end

    def remove_null_bytes(value)
      return '' if value.nil?

      value.to_s.gsub("\x00", '').gsub('%00', '')
    end
  end

  def initialize(params = {})
    @params = params
    @errors = []
  end

  def call
    validate_all
    @errors.empty? ? Result.success(@params) : Result.failure(@errors.join('; '))
  end

  private

  def validate_all
    @params.each do |key, value|
      next unless value.is_a?(String)

      if self.class.contains_sql_injection?(value)
        @errors << "Potential SQL injection in '#{key}'"
      end

      if self.class.contains_xss?(value)
        @errors << "Potential XSS in '#{key}'"
      end
    end
  end
end
