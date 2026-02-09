# frozen_string_literal: true

module Mcp
  class McpAuth
    RATE_LIMIT_PREFIX = 'mcp:rate:'
    AUDIT_LOG_PREFIX = 'mcp:audit:'

    attr_reader :api_key, :client_id, :scopes

    def initialize(api_key:)
      @api_key = api_key
      @client_id = Digest::SHA256.hexdigest(api_key.to_s)[0..11]
      @scopes = McpConfig.scopes_for_key(api_key)
    end

    def authenticate!
      raise AuthenticationError, 'Invalid API key' unless McpConfig.valid_api_key?(api_key)
      raise RateLimitError, 'Rate limit exceeded' if rate_limited?

      increment_request_count
      true
    end

    def authorize!(required_scope)
      return true if scopes.include?('admin')
      return true if scopes.include?(required_scope)

      # Check wildcard scopes (e.g., "devices:*" matches "devices:read")
      category = required_scope.split(':').first
      return true if scopes.include?("#{category}:*")

      raise AuthorizationError, "Insufficient scope: #{required_scope} required"
    end

    def rate_limited?
      unless redis_available?
        Rails.logger.warn("[MCP Auth] Redis unavailable - rate limiting fail-closed")
        return true
      end

      count = Redis.current.get(rate_limit_key).to_i
      count >= McpConfig.rate_limit_requests
    end

    def remaining_requests
      return McpConfig.rate_limit_requests unless redis_available?

      count = Redis.current.get(rate_limit_key).to_i
      [McpConfig.rate_limit_requests - count, 0].max
    end

    def audit_log(action:, resource:, details: {})
      log_entry = {
        timestamp: Time.current.iso8601,
        client_id: client_id,
        action: action,
        resource: resource,
        details: details,
        ip_address: RequestStore.store[:ip_address]
      }

      if defined?(AuditLog)
        AuditLog.create(
          action: "mcp:#{action}",
          metadata: log_entry
        )
      end

      Rails.logger.info("[MCP Audit] #{log_entry.to_json}")
      log_entry
    rescue StandardError => e
      Rails.logger.warn("[MCP Audit] Failed to log: #{e.message}")
    end

    class AuthenticationError < StandardError; end
    class AuthorizationError < StandardError; end
    class RateLimitError < StandardError; end

    private

    def rate_limit_key
      "#{RATE_LIMIT_PREFIX}#{client_id}:#{Time.current.to_i / McpConfig.rate_limit_window}"
    end

    def increment_request_count
      return unless redis_available?

      key = rate_limit_key
      Redis.current.multi do |multi|
        multi.incr(key)
        multi.expire(key, McpConfig.rate_limit_window)
      end
    end

    def redis_available?
      defined?(Redis) && Redis.current.ping == 'PONG'
    rescue StandardError
      false
    end
  end
end
