# frozen_string_literal: true

# Controller concern for automatic input sanitization.
# Include in controllers that need parameter sanitization.
#
# Usage:
#   class MyController < ApplicationController
#     include InputSanitization
#   end
module InputSanitization
  extend ActiveSupport::Concern

  included do
    before_action :sanitize_request_params
  end

  private

  def sanitize_request_params
    sanitize_hash(params)
    log_sanitization if @sanitization_applied
  end

  def sanitize_hash(hash, depth: 0)
    return if depth > 10 # prevent infinite recursion

    hash.each do |key, value|
      case value
      when String
        sanitized = sanitize_string_param(value)
        if sanitized != value
          @sanitization_applied = true
          @sanitized_fields ||= []
          @sanitized_fields << key.to_s
          hash[key] = sanitized
        end
      when ActionController::Parameters, Hash
        sanitize_hash(value, depth: depth + 1)
      when Array
        value.each_with_index do |item, i|
          if item.is_a?(String)
            sanitized = sanitize_string_param(item)
            if sanitized != item
              @sanitization_applied = true
              value[i] = sanitized
            end
          elsif item.is_a?(Hash) || item.is_a?(ActionController::Parameters)
            sanitize_hash(item, depth: depth + 1)
          end
        end
      end
    end
  end

  def sanitize_string_param(value)
    sanitized = InputValidator.remove_null_bytes(value)
    sanitized = sanitized.unicode_normalize(:nfc) if sanitized.respond_to?(:unicode_normalize)
    sanitized.strip
  end

  def log_sanitization
    return unless @sanitized_fields&.any?

    Rails.logger.info(
      "[InputSanitization] Sanitized fields: #{@sanitized_fields.join(', ')} " \
      "for #{request.method} #{request.path}"
    )
  end

  # --- Type Coercion Helpers ---

  def coerce_to_integer(value, default: nil)
    return default if value.nil?

    Integer(value)
  rescue ArgumentError, TypeError
    default
  end

  def coerce_to_float(value, default: nil)
    return default if value.nil?

    Float(value)
  rescue ArgumentError, TypeError
    default
  end

  def coerce_to_boolean(value, default: false)
    return default if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  # Whitelist parameters, rejecting any not in allowed list
  def whitelist_params(allowed_keys)
    params.slice(*allowed_keys)
  end
end
