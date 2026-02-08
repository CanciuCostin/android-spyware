# frozen_string_literal: true

ActiveAdmin.register_page "Security Analysis" do
  menu label: "🛡️ Security Analysis", parent: "🧠 AI", priority: 5

  content title: "🛡️ Security Analysis Dashboard" do
    devices = Smartphone.joins(:apk_installation)
                        .where("apk_installations.status = ?", "installed")

    # Threat overview
    recent_events = begin
      SecurityEvent.where('detected_at > ?', 24.hours.ago).order(detected_at: :desc).limit(50)
    rescue StandardError
      []
    end

    critical_count = recent_events.count { |e| e.severity == 'critical' }
    high_count = recent_events.count { |e| e.severity == 'high' }
    medium_count = recent_events.count { |e| e.severity == 'medium' }
    low_count = recent_events.count { |e| e.severity == 'low' }

    # Stats
    div class: "stats-grid" do
      [
        ["🚨", critical_count, "Critical", "red"],
        ["⚠️", high_count, "High", "amber"],
        ["🔶", medium_count, "Medium", "blue"],
        ["ℹ️", low_count, "Low", "green"]
      ].each do |icon, val, label, color|
        div class: "stat-card", "data-color": color do
          div class: "stat-icon" do
            text_node icon
          end
          span val.to_s, class: "stat-value"
          span label, class: "stat-label"
        end
      end
    end

    # Recent Security Events
    panel "Recent Security Events (24h)" do
      if recent_events.empty?
        div class: "empty-state" do
          h3 "No security events in the last 24 hours"
          para "All monitored devices are operating normally."
        end
      else
        table_for recent_events do
          column("Time") { |e| e.detected_at.strftime('%Y-%m-%d %H:%M') }
          column("Device") { |e| e.device_id }
          column("Type") { |e| e.event_type.titleize }
          column("Severity") do |e|
            severity_icons = { 'critical' => '🚨', 'high' => '⚠️', 'medium' => '🔶', 'low' => 'ℹ️' }
            status_tag(e.severity, class: e.severity) do
              text_node "#{severity_icons[e.severity] || '•'} #{e.severity.upcase}"
            end
          end
          column("Details") { |e| truncate(e.details.to_s, length: 120) }
        end
      end
    end

    # GPS Spoofing Alerts
    panel "GPS Spoofing Alerts" do
      gps_events = recent_events.select { |e| e.event_type == 'gps_analysis' }
      if gps_events.empty?
        para "No GPS spoofing alerts detected."
      else
        table_for gps_events do
          column("Time") { |e| e.detected_at.strftime('%Y-%m-%d %H:%M') }
          column("Device") { |e| e.device_id }
          column("Severity") { |e| status_tag(e.severity) }
          column("Details") do |e|
            parsed = begin; JSON.parse(e.details); rescue; {}; end
            if parsed['alerts'].present?
              parsed['alerts'].map { |a| a['detail'] }.join('; ')
            else
              e.details.to_s.truncate(200)
            end
          end
        end
      end
    end

    # Media Integrity Reports
    panel "Media Integrity Reports" do
      media_events = recent_events.select { |e| e.event_type == 'media_analysis' }
      if media_events.empty?
        para "No media integrity issues detected."
      else
        table_for media_events do
          column("Time") { |e| e.detected_at.strftime('%Y-%m-%d %H:%M') }
          column("Device") { |e| e.device_id }
          column("Severity") { |e| status_tag(e.severity) }
          column("Findings") do |e|
            parsed = begin; JSON.parse(e.details); rescue; {}; end
            if parsed['findings'].present?
              parsed['findings'].map { |f| f['finding'] }.join(', ')
            else
              e.details.to_s.truncate(200)
            end
          end
        end
      end
    end

    # Per-device security status
    panel "Device Security Status" do
      table_for devices do
        column("Device") { |d| d.name || d.device_id }
        column("Device ID") { |d| d.device_id }
        column("Last Activity") { |d| d.updated_at&.strftime('%Y-%m-%d %H:%M') || 'N/A' }
        column("Security Events (24h)") do |d|
          count = recent_events.count { |e| e.device_id == d.device_id }
          count.zero? ? status_tag("Clean", class: "ok") : status_tag("#{count} events", class: "warning")
        end
      end
    end
  end
end
