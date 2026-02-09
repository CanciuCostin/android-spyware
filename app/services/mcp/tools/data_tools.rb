# frozen_string_literal: true

module Mcp
  module Tools
    class DataTools
      def initialize(server)
        @server = server
      end

      def register
        register_get_locations
        register_get_sms_messages
        register_get_call_logs
        register_get_contacts
        register_get_photos
      end

      private

      def register_get_locations
        @server.register_tool(
          name: 'get_locations',
          description: 'Get GPS location history for a device. Returns latitude, longitude, and timestamps.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              limit: { type: 'integer', description: 'Max results (default: 50)', default: 50 },
              since: { type: 'string', description: 'ISO 8601 timestamp to filter from' },
              until: { type: 'string', description: 'ISO 8601 timestamp to filter until' }
            },
            required: ['device_id']
          },
          scope: 'data:read'
        ) do |args|
          device = find_device!(args[:device_id])
          locations = device.geo_locations.order(created_at: :desc)
          locations = locations.where('created_at >= ?', Time.parse(args[:since])) if args[:since].present?
          locations = locations.where('created_at <= ?', Time.parse(args[:until])) if args[:until].present?
          locations = locations.limit([[args[:limit] || 50, 1].max, McpConfig.max_results].min)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                locations: locations.map { |l|
                  { latitude: l.latitude, longitude: l.longitude, recorded_at: l.created_at.iso8601 }
                },
                count: locations.size
              }.to_json
            }]
          }
        end
      end

      def register_get_sms_messages
        @server.register_tool(
          name: 'get_sms_messages',
          description: 'Get SMS messages dumped from a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              page: { type: 'integer', description: 'Page number', default: 1 },
              per_page: { type: 'integer', description: 'Results per page', default: 25 }
            },
            required: ['device_id']
          },
          scope: 'data:read'
        ) do |args|
          device = find_device!(args[:device_id])
          page = [args[:page] || 1, 1].max
          per_page = [[args[:per_page] || McpConfig.default_page_size, 1].max, McpConfig.max_results].min

          messages = device.sms_messages.order(created_at: :desc)
          total = messages.count
          records = messages.offset((page - 1) * per_page).limit(per_page)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                messages: records.map { |m|
                  { id: m.id, filename: m.filename, created_at: m.created_at.iso8601 }
                },
                pagination: { page: page, per_page: per_page, total: total }
              }.to_json
            }]
          }
        end
      end

      def register_get_call_logs
        @server.register_tool(
          name: 'get_call_logs',
          description: 'Get call log entries from a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              page: { type: 'integer', description: 'Page number', default: 1 },
              per_page: { type: 'integer', description: 'Results per page', default: 25 }
            },
            required: ['device_id']
          },
          scope: 'data:read'
        ) do |args|
          device = find_device!(args[:device_id])
          page = [args[:page] || 1, 1].max
          per_page = [[args[:per_page] || McpConfig.default_page_size, 1].max, McpConfig.max_results].min

          logs = device.call_logs.order(created_at: :desc)
          total = logs.count
          records = logs.offset((page - 1) * per_page).limit(per_page)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                call_logs: records.map { |c|
                  { id: c.id, filename: c.filename, date: c.date, created_at: c.created_at.iso8601 }
                },
                pagination: { page: page, per_page: per_page, total: total }
              }.to_json
            }]
          }
        end
      end

      def register_get_contacts
        @server.register_tool(
          name: 'get_contacts',
          description: 'Get contacts dumped from a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              page: { type: 'integer', description: 'Page number', default: 1 },
              per_page: { type: 'integer', description: 'Results per page', default: 25 }
            },
            required: ['device_id']
          },
          scope: 'data:read'
        ) do |args|
          device = find_device!(args[:device_id])
          page = [args[:page] || 1, 1].max
          per_page = [[args[:per_page] || McpConfig.default_page_size, 1].max, McpConfig.max_results].min

          contacts = device.contacts.order(created_at: :desc)
          total = contacts.count
          records = contacts.offset((page - 1) * per_page).limit(per_page)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                contacts: records.map { |c|
                  { id: c.id, filename: c.filename, created_at: c.created_at.iso8601 }
                },
                pagination: { page: page, per_page: per_page, total: total }
              }.to_json
            }]
          }
        end
      end

      def register_get_photos
        @server.register_tool(
          name: 'get_photos',
          description: 'Get photos captured from a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              page: { type: 'integer', description: 'Page number', default: 1 },
              per_page: { type: 'integer', description: 'Results per page', default: 25 }
            },
            required: ['device_id']
          },
          scope: 'data:read'
        ) do |args|
          device = find_device!(args[:device_id])
          page = [args[:page] || 1, 1].max
          per_page = [[args[:per_page] || McpConfig.default_page_size, 1].max, McpConfig.max_results].min

          photos = device.pictures.order(created_at: :desc)
          total = photos.count
          records = photos.offset((page - 1) * per_page).limit(per_page)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                photos: records.map { |p|
                  { id: p.id, filename: p.filename, created_at: p.created_at.iso8601 }
                },
                pagination: { page: page, per_page: per_page, total: total }
              }.to_json
            }]
          }
        end
      end

      def find_device!(device_id)
        Smartphone.find_by!(device_id: device_id)
      rescue ActiveRecord::RecordNotFound
        raise McpServer::ToolNotFoundError, "Device not found: #{device_id}"
      end
    end
  end
end
