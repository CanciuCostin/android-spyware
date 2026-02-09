ActiveAdmin.register_page "Image Recognition" do
  menu label: "🖼️ Image Recognition", parent: "🧠 AI", priority: 8

  content title: "🖼️ AI Image Recognition" do
    devices = Smartphone.all

    # API status
    div class: "api-status" do
      google_ok = ENV['GOOGLE_VISION_API_KEY'].present?
      gemini_ok = ENV['GEMINI_API_KEY'].present?
      span "API Status: "
      span google_ok ? "✅ Google Vision" : "❌ Google Vision", class: google_ok ? "status-ok" : "status-off"
      span " | "
      span gemini_ok ? "✅ Gemini Vision" : "❌ Gemini Vision", class: gemini_ok ? "status-ok" : "status-off"
      span " | ✅ EXIF Metadata (always available)"
    end

    # Image upload analysis
    div class: "image-section" do
      h3 "Analyze Image"
      div class: "image-controls" do
        input type: "file", id: "image-upload-input", accept: "image/*"
        button "🔍 Full Analysis", id: "image-full-btn", class: "button", style: "margin-left: 12px;"
        button "📄 OCR", id: "image-ocr-btn", class: "button"
        button "👤 Faces", id: "image-faces-btn", class: "button"
        button "🏷️ Objects", id: "image-objects-btn", class: "button"
        button "ℹ️ Metadata", id: "image-metadata-btn", class: "button"
      end
    end

    # Device images
    unless devices.empty?
      div class: "image-section", style: "margin-top: 16px;" do
        h3 "Analyze Device Images"
        div class: "device-controls" do
          label "Device:", for: "image-device-select"
          select id: "image-device-select" do
            devices.each do |device|
              option(value: device.id) { "#{device.name} (#{device.device_id})" }
            end
          end
          button "📱 Analyze Device Images", id: "image-device-btn", class: "button", style: "margin-left: 12px;"
        end
      end
    end

    # Output
    div class: "image-output" do
      pre id: "image-result", style: "white-space: pre-wrap; max-height: 600px; overflow: auto; background: #1e293b; padding: 16px; border-radius: 8px; color: #e2e8f0;"
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          function imageApiCall(endpoint) {
            var input = document.getElementById('image-upload-input');
            if (!input.files.length) { alert('Please select an image file.'); return; }
            var formData = new FormData();
            formData.append('image', input.files[0]);
            fetch(endpoint, { method: 'POST', body: formData })
              .then(function(r) { return r.json(); })
              .then(function(data) {
                document.getElementById('image-result').textContent = JSON.stringify(data, null, 2);
              })
              .catch(function(e) { document.getElementById('image-result').textContent = 'Error: ' + e.message; });
          }

          var actions = {
            'image-full-btn': '/api/ai/image/analyze',
            'image-ocr-btn': '/api/ai/image/ocr',
            'image-faces-btn': '/api/ai/image/faces',
            'image-objects-btn': '/api/ai/image/objects',
            'image-metadata-btn': '/api/ai/image/metadata'
          };

          Object.keys(actions).forEach(function(id) {
            var el = document.getElementById(id);
            if (el) el.addEventListener('click', function() { imageApiCall(actions[id]); });
          });

          var deviceBtn = document.getElementById('image-device-btn');
          if (deviceBtn) {
            deviceBtn.addEventListener('click', function() {
              var deviceId = document.getElementById('image-device-select').value;
              fetch('/api/ai/image/device_images/' + deviceId)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                  document.getElementById('image-result').textContent = JSON.stringify(data, null, 2);
                });
            });
          }
        });
      JS
    end

    style do
      raw <<~CSS
        .api-status { background: #1e293b; padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; color: #94a3b8; }
        .status-ok { color: #10b981; } .status-off { color: #64748b; }
        .image-section { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
        .image-section h3 { color: #e2e8f0; margin-top: 0; }
        .image-controls, .device-controls { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
        .device-controls label { color: #94a3b8; font-weight: 600; }
        .device-controls select { background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 6px 10px; }
        .button { background: #f59e0b; color: #1e293b; border: none; border-radius: 4px; padding: 8px 16px; cursor: pointer; font-weight: 600; }
        .button:hover { background: #d97706; }
      CSS
    end
  end
end
