ActiveAdmin.register_page "Keylog Analytics" do
  menu parent: "📦 Data", priority: 2, label: "📊 Keylog Analytics"

  content title: "📊 Keylog Analytics Dashboard" do
    devices = Smartphone.all

    if devices.empty?
      div class: "empty-state" do
        h2 "No Devices Available"
        para "Connect a device to view keylog analytics."
      end
    else
      # Consent status indicator
      div class: "consent-banner", id: "consent-status-banner" do
        span "🔒 Consent Status: ", style: "font-weight: bold;"
        span "Checking...", id: "consent-status-text", style: "color: #f59e0b;"
      end

      # Device selector
      div class: "analytics-header" do
        div class: "device-selector" do
          label "Select Device:", for: "analytics-device-select"
          select id: "analytics-device-select", class: "device-select-dropdown" do
            devices.each do |device|
              consent = DeviceConsent.find_by(device_id: device.id, consent_type: 'data_collection')
              consent_icon = consent&.active? ? '✅' : '⚠️'
              option value: device.id do
                text_node "#{consent_icon} #{device.name} (#{device.device_id})"
              end
            end
          end
        end
      end

      # Date range selector
      div class: "date-range-selector" do
        button "Last 7 Days", class: "date-range-btn", data: { days: 7 }
        button "Last 30 Days", class: "date-range-btn active", data: { days: 30 }
        button "Last 90 Days", class: "date-range-btn", data: { days: 90 }
        input type: "text", id: "analytics-custom-date", class: "custom-date-picker", placeholder: "Custom Range..."
      end

      # Summary stats
      div class: "stats-overview-grid", id: "keylog-stats-overview" do
        %w[total_keystrokes unique_apps active_days avg_keystrokes_per_day].each do |metric|
          div class: "metric-item" do
            div(class: "metric-value") { span "—", id: "stat-#{metric}", class: "big-number" }
            div(class: "metric-label") { metric.titleize }
          end
        end
      end

      # Export buttons
      div class: "export-bar", style: "margin: 15px 0; text-align: right;" do
        button "📥 Export CSV", id: "export-csv-btn", class: "button", style: "margin-right: 8px;"
        button "📥 Export JSON", id: "export-json-btn", class: "button"
      end

      # Charts grid
      div class: "charts-grid" do
        # Activity Timeline
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Typing Activity Over Time", class: "chart-title"
            div class: "chart-actions" do
              select id: "timeline-granularity", style: "margin-right: 8px;" do
                option(value: "daily") { "Daily" }
                option(value: "hourly") { "Hourly" }
              end
            end
          end
          div class: "chart-canvas-wrapper large" do
            canvas id: "keylog-activity-chart"
          end
        end

        # App Usage Distribution
        div class: "chart-container half-width" do
          div class: "chart-header" do
            h3 "Top Apps by Input Volume", class: "chart-title"
          end
          div class: "chart-canvas-wrapper" do
            canvas id: "keylog-app-usage-chart"
          end
        end

        # Peak Hours
        div class: "chart-container half-width" do
          div class: "chart-header" do
            h3 "Peak Activity Hours", class: "chart-title"
          end
          div class: "chart-canvas-wrapper" do
            canvas id: "keylog-peak-hours-chart"
          end
        end

        # Hourly Heatmap
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Activity Heatmap (Hour × Day)", class: "chart-title"
          end
          div class: "chart-canvas-wrapper large" do
            canvas id: "keylog-heatmap-chart"
          end
        end

        # Session & Word Count Summary
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Sessions & Word Count", class: "chart-title"
          end
          div id: "session-summary", class: "metric-grid", style: "padding: 20px;" do
            # Populated by JS
          end
        end
      end
    end

    # JavaScript initialization
    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          if (typeof KeylogDashboard !== 'undefined') {
            window.keylogDashboard = new KeylogDashboard();
          }
        });
      JS
    end

    # Styles
    style do
      raw <<~CSS
        .consent-banner {
          background: #1e293b; padding: 10px 16px; border-radius: 6px;
          margin-bottom: 16px; border-left: 4px solid #f59e0b;
        }
        .consent-banner.granted { border-left-color: #10b981; }
        .consent-banner.denied { border-left-color: #ef4444; }
        .export-bar .button { background: #374151; color: #e5e7eb; border: 1px solid #4b5563; border-radius: 4px; padding: 6px 14px; cursor: pointer; }
        .export-bar .button:hover { background: #4b5563; }
      CSS
    end
  end
end
