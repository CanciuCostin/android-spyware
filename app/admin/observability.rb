# frozen_string_literal: true

ActiveAdmin.register_page 'Observability' do
  menu priority: 15, label: '📊 Observability'

  content title: '📊 Observability Dashboard' do
    # --- Summary Cards ---
    health = begin
      {
        database: ActiveRecord::Base.connection.execute('SELECT 1') && 'ok',
        redis: (RedisPool.with { |r| r.ping } && 'ok' rescue 'error'),
        uptime: ((Time.current - Rails.application.config.boot_time).to_i rescue 0)
      }
    rescue StandardError
      { database: 'error', redis: 'error', uptime: 0 }
    end

    error_summary = ErrorTracker.summary
    devices_total = Smartphone.count rescue 0
    active_devices = begin
      Smartphone.joins(:apk_installation)
                .where('apk_installations.status = ?', 'installed')
                .where('smartphones.updated_at > ?', 5.minutes.ago).count
    rescue StandardError
      0
    end
    ws_connections = (ActionCable.server.connections.size rescue 0)

    # --- Health Banner ---
    div class: 'observability-banner' do
      style do
        text_node <<~CSS.html_safe
          .observability-banner{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:24px}
          .obs-card{background:#1e1e2e;border-radius:12px;padding:20px 24px;flex:1;min-width:180px;border:1px solid #333}
          .obs-card h4{color:#888;font-size:12px;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px}
          .obs-card .obs-val{font-size:28px;font-weight:700;color:#e0e0e0}
          .obs-card .obs-val.ok{color:#4ade80}
          .obs-card .obs-val.error{color:#f87171}
          .obs-card .obs-val.warn{color:#fbbf24}
          .obs-section{background:#1e1e2e;border-radius:12px;padding:24px;margin-bottom:24px;border:1px solid #333}
          .obs-section h3{color:#e0e0e0;margin:0 0 16px;font-size:18px}
          .obs-table{width:100%;border-collapse:collapse}
          .obs-table th{text-align:left;color:#888;font-size:12px;text-transform:uppercase;letter-spacing:1px;padding:8px 12px;border-bottom:1px solid #333}
          .obs-table td{color:#e0e0e0;padding:8px 12px;border-bottom:1px solid #2a2a3a;font-size:14px}
          .obs-table tr:hover td{background:#252538}
          .badge-ok{background:#064e3b;color:#4ade80;padding:2px 10px;border-radius:8px;font-size:12px}
          .badge-error{background:#7f1d1d;color:#f87171;padding:2px 10px;border-radius:8px;font-size:12px}
          .badge-warn{background:#78350f;color:#fbbf24;padding:2px 10px;border-radius:8px;font-size:12px}
          .error-entry{background:#1a1a2e;border-radius:8px;padding:12px 16px;margin-bottom:8px;border-left:3px solid #f87171}
          .error-entry .err-time{color:#888;font-size:11px}
          .error-entry .err-msg{color:#e0e0e0;font-size:14px;margin-top:4px}
          .error-entry .err-class{color:#f87171;font-size:12px;font-family:monospace}
          .metrics-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
        CSS
      end

      # Summary cards
      [
        ['Database', health[:database], health[:database] == 'ok' ? 'ok' : 'error'],
        ['Redis', health[:redis], health[:redis] == 'ok' ? 'ok' : 'error'],
        ['Active Devices', "#{active_devices}/#{devices_total}", active_devices > 0 ? 'ok' : 'warn'],
        ['WebSocket Conns', ws_connections.to_s, 'ok'],
        ['Uptime', "#{health[:uptime] / 3600}h #{(health[:uptime] % 3600) / 60}m", 'ok'],
        ['Error Rate', "#{error_summary[:error_rate_per_minute]}/min", error_summary[:spike] ? 'error' : 'ok']
      ].each do |label, value, status|
        div class: 'obs-card' do
          h4 label
          div class: "obs-val #{status}" do
            text_node value.to_s
          end
        end
      end
    end

    # --- Error Tracking Section ---
    div class: 'obs-section' do
      h3 '🚨 Recent Errors'

      if error_summary[:recent].any?
        # Error category breakdown
        if error_summary[:by_category].any?
          div class: 'metrics-grid', style: 'margin-bottom:16px' do
            error_summary[:by_category].each do |cat, count|
              div class: 'obs-card' do
                h4 cat.to_s.titleize
                div(class: 'obs-val warn') { text_node count.to_s }
              end
            end
          end
        end

        # Recent error list
        error_summary[:recent].first(10).each do |err|
          div class: 'error-entry' do
            div class: 'err-time' do
              text_node "#{err[:timestamp]} · #{err[:category]}"
              text_node " · Device: #{err[:device_id]}" if err[:device_id]
            end
            div(class: 'err-class') { text_node err[:error_class].to_s }
            div(class: 'err-msg') { text_node err[:message] }
          end
        end
      else
        para 'No recent errors recorded.', style: 'color:#888'
      end
    end

    # --- Metrics Section ---
    div class: 'obs-section' do
      h3 '📈 Application Metrics'

      counters = {
        'Commands Sent' => MetricsService.get_counter(:commands_sent_total),
        'Commands Failed' => MetricsService.get_counter(:commands_failed_total),
        'Errors Total' => MetricsService.get_counter(:errors_total),
        'Uploads Completed' => MetricsService.get_counter(:uploads_completed_total)
      }

      table class: 'obs-table' do
        thead do
          tr do
            th 'Metric'
            th 'Value'
          end
        end
        tbody do
          counters.each do |label, val|
            tr do
              td label
              td val.to_s
            end
          end
        end
      end
    end

    # --- Histogram Section ---
    div class: 'obs-section' do
      h3 '⏱️ Latency Histograms'

      histograms = {
        'Command Response Time' => MetricsService.get_histogram(:command_response_time),
        'Upload Duration' => MetricsService.get_histogram(:upload_duration)
      }

      table class: 'obs-table' do
        thead do
          tr do
            th 'Metric'
            th 'Count'
            th 'Sum (s)'
            th 'Avg (s)'
          end
        end
        tbody do
          histograms.each do |label, data|
            tr do
              td label
              if data
                td data[:count].to_s
                td data[:sum].round(3).to_s
                td(data[:count] > 0 ? (data[:sum] / data[:count]).round(3).to_s : '0')
              else
                td '0'
                td '0'
                td '0'
              end
            end
          end
        end
      end
    end

    # --- Endpoints Reference ---
    div class: 'obs-section' do
      h3 '🔗 Observability Endpoints'

      table class: 'obs-table' do
        thead do
          tr do
            th 'Endpoint'
            th 'Description'
          end
        end
        tbody do
          [
            ['/health', 'Full health check with all dependencies'],
            ['/health/live', 'Liveness probe (is the process alive?)'],
            ['/health/ready', 'Readiness probe (DB, Redis, ActionCable)'],
            ['/health/startup', 'Startup probe (initial boot readiness)'],
            ['/metrics', 'Prometheus-format metrics export']
          ].each do |path, desc|
            tr do
              td do
                a href: path do
                  code path
                end
              end
              td desc
            end
          end
        end
      end
    end
  end
end
