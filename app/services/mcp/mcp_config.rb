# frozen_string_literal: true

module Mcp
  class McpConfig
    DEFAULTS = {
      server_name: 'eaglespy-mcp',
      server_version: '1.0.0',
      protocol_version: '2024-11-05',
      max_results_per_page: 100,
      default_page_size: 25,
      rate_limit_requests: 60,
      rate_limit_window: 60, # seconds
      command_timeout: 300,   # seconds
      stream_heartbeat: 30,   # seconds
      allowed_scopes: %w[
        devices:read devices:write
        data:read data:write
        commands:execute commands:schedule
        analysis:read
        admin
      ].freeze
    }.freeze

    class << self
      def server_name
        env_or_default('MCP_SERVER_NAME', DEFAULTS[:server_name])
      end

      def server_version
        DEFAULTS[:server_version]
      end

      def protocol_version
        DEFAULTS[:protocol_version]
      end

      def api_keys
        @api_keys ||= parse_api_keys
      end

      def database_config
        Rails.configuration.database_configuration[Rails.env]
      end

      def max_results
        env_or_default('MCP_MAX_RESULTS', DEFAULTS[:max_results_per_page]).to_i
      end

      def default_page_size
        env_or_default('MCP_PAGE_SIZE', DEFAULTS[:default_page_size]).to_i
      end

      def rate_limit_requests
        env_or_default('MCP_RATE_LIMIT', DEFAULTS[:rate_limit_requests]).to_i
      end

      def rate_limit_window
        env_or_default('MCP_RATE_WINDOW', DEFAULTS[:rate_limit_window]).to_i
      end

      def command_timeout
        env_or_default('MCP_COMMAND_TIMEOUT', DEFAULTS[:command_timeout]).to_i
      end

      def stream_heartbeat
        env_or_default('MCP_STREAM_HEARTBEAT', DEFAULTS[:stream_heartbeat]).to_i
      end

      def allowed_scopes
        DEFAULTS[:allowed_scopes]
      end

      def valid_api_key?(key)
        api_keys.key?(key)
      end

      def scopes_for_key(key)
        api_keys.dig(key, :scopes) || []
      end

      def reset!
        @api_keys = nil
      end

      private

      def env_or_default(key, default)
        ENV.fetch(key, default)
      end

      # Format: MCP_API_KEYS="key1:scope1,scope2;key2:scope3,scope4"
      def parse_api_keys
        raw = ENV.fetch('MCP_API_KEYS', '')
        return {} if raw.blank?

        raw.split(';').each_with_object({}) do |entry, hash|
          key, scopes_str = entry.split(':', 2)
          next if key.blank?

          scopes = (scopes_str || '').split(',').map(&:strip)
          hash[key.strip] = { scopes: scopes }
        end
      end
    end
  end
end
