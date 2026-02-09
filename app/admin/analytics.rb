ActiveAdmin.register_page "Analytics" do
  menu priority: 3, label: "📊 Analytics"

  content title: "📊 Analytics Dashboard" do
    # Device selector
    devices = Smartphone.all
    
    if devices.empty?
      div class: "empty-state" do
        h2 "No Devices Available"
        para "Connect a device to view analytics."
      end
    else
      # Device selector dropdown
      div class: "analytics-header" do
        div class: "device-selector" do
          label "Select Device:", for: "device-select"
          select id: "device-select", class: "device-select-dropdown" do
            devices.each do |device|
              option value: device.id do
                text_node "#{device.name} (#{device.device_id})"
              end
            end
          end
        end
      end

      # Date range selector
      div class: "date-range-selector" do
        button "Last 7 Days", class: "date-range-btn active", data: { date_range: 7 }
        button "Last 30 Days", class: "date-range-btn", data: { date_range: 30 }
        button "Last 90 Days", class: "date-range-btn", data: { date_range: 90 }
        input type: "text", id: "custom-date-picker", class: "custom-date-picker", placeholder: "Custom Range..."
      end

      # Stats Overview
      div class: "stats-overview-grid", id: "stats-overview" do
        # Will be populated by JavaScript
      end

      # Charts Grid
      div class: "charts-grid" do
        # Activity Timeline (Full Width)
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Device Activity Timeline", class: "chart-title"
            div class: "chart-actions" do
              div class: "export-dropdown" do
                button "Export ⬇", class: "chart-export-btn", onclick: "toggleExportMenu(this)"
                div class: "export-menu" do
                  button "PNG", class: "export-menu-item", onclick: "exportChart('activity-timeline-chart', 'png')"
                  button "PDF", class: "export-menu-item", onclick: "exportChart('activity-timeline-chart', 'pdf')"
                end
              end
              div class: "realtime-indicator" do
                text_node "Live Updates"
              end
            end
          end
          div class: "chart-canvas-wrapper large" do
            canvas id: "activity-timeline-chart"
          end
        end

        # Location Heatmap (Full Width)
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Location Heatmap", class: "chart-title"
            div class: "chart-actions" do
              button "Export ⬇", class: "chart-export-btn", onclick: "exportChart('location-heatmap', 'png')"
            end
          end
          div class: "chart-canvas-wrapper heatmap" do
            div id: "location-heatmap"
          end
        end

        # App Usage (Half Width)
        div class: "chart-container half-width" do
          div class: "chart-header" do
            h3 "App Usage Statistics", class: "chart-title"
            div class: "chart-actions" do
              button "Export ⬇", class: "chart-export-btn", onclick: "exportChart('app-usage-chart', 'png')"
            end
          end
          div class: "chart-canvas-wrapper" do
            canvas id: "app-usage-chart"
          end
        end

        # Call/SMS Stats (Half Width)
        div class: "chart-container half-width" do
          div class: "chart-header" do
            h3 "Call & SMS Statistics", class: "chart-title"
            div class: "chart-actions" do
              button "Export ⬇", class: "chart-export-btn", onclick: "exportChart('call-sms-chart', 'png')"
            end
          end
          div class: "chart-canvas-wrapper" do
            canvas id: "call-sms-chart"
          end
        end

        # Battery & Network (Full Width)
        div class: "chart-container full-width" do
          div class: "chart-header" do
            h3 "Battery & Network Trends", class: "chart-title"
            div class: "chart-actions" do
              button "Export ⬇", class: "chart-export-btn", onclick: "exportChart('battery-network-chart', 'png')"
            end
          end
          div class: "chart-canvas-wrapper" do
            canvas id: "battery-network-chart"
          end
        end
      end
    end

    # JavaScript initialization
    script do
      text_node <<~JS.html_safe
        document.body.dataset.controller = 'charts';
        
        // Handle device selection
        const deviceSelect = document.getElementById('device-select');
        if (deviceSelect) {
          deviceSelect.addEventListener('change', function() {
            document.body.dataset.deviceId = this.value;
            if (window.chartManager) {
              window.chartManager.refreshCharts();
            }
          });
          
          // Set initial device
          if (deviceSelect.options.length > 0) {
            document.body.dataset.deviceId = deviceSelect.value;
          }
        }

        // Export menu toggle
        window.toggleExportMenu = function(btn) {
          const dropdown = btn.closest('.export-dropdown');
          dropdown.classList.toggle('active');
          
          // Close when clicking outside
          const closeHandler = (e) => {
            if (!dropdown.contains(e.target)) {
              dropdown.classList.remove('active');
              document.removeEventListener('click', closeHandler);
            }
          };
          
          if (dropdown.classList.contains('active')) {
            setTimeout(() => document.addEventListener('click', closeHandler), 0);
          }
        };

        // Date range button handling
        document.querySelectorAll('.date-range-btn').forEach(btn => {
          btn.addEventListener('click', function() {
            document.querySelectorAll('.date-range-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
          });
        });
      JS
    end
  end
end
