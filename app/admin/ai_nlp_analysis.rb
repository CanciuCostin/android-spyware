ActiveAdmin.register_page "NLP Analysis" do
  menu label: "📝 NLP Analysis", parent: "🧠 AI", priority: 7

  content title: "📝 NLP Text Analysis" do
    devices = Smartphone.all

    # Manual text analysis
    div class: "nlp-section" do
      h3 "Analyze Custom Text"
      div class: "nlp-input" do
        textarea id: "nlp-text-input", rows: 5, placeholder: "Paste text here for analysis...",
                 style: "width: 100%; background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 10px; font-size: 14px;"
      end
      div class: "nlp-actions", style: "margin-top: 8px;" do
        button "🔍 Full Analysis", id: "nlp-full-btn", class: "button"
        button "🏷️ Entities", id: "nlp-entities-btn", class: "button"
        button "😊 Sentiment", id: "nlp-sentiment-btn", class: "button"
        button "🌐 Language", id: "nlp-language-btn", class: "button"
        button "🔒 PII Detection", id: "nlp-pii-btn", class: "button"
      end
    end

    # Device message analysis
    unless devices.empty?
      div class: "nlp-section", style: "margin-top: 24px;" do
        h3 "Analyze Device Messages"
        div class: "nlp-device-controls" do
          label "Device:", for: "nlp-device-select"
          select id: "nlp-device-select" do
            devices.each do |device|
              option(value: device.id) { "#{device.name} (#{device.device_id})" }
            end
          end

          label "Limit:", for: "nlp-limit", style: "margin-left: 12px;"
          select id: "nlp-limit" do
            [10, 25, 50, 100].each { |n| option(value: n) { n.to_s } }
          end

          button "📱 Analyze Messages", id: "nlp-device-btn", class: "button", style: "margin-left: 12px;"
        end
      end
    end

    # Output
    div class: "nlp-output" do
      pre id: "nlp-result", style: "white-space: pre-wrap; max-height: 600px; overflow: auto; background: #1e293b; padding: 16px; border-radius: 8px; color: #e2e8f0;"
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          function nlpCall(endpoint, body) {
            fetch(endpoint, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(body)
            })
            .then(function(r) { return r.json(); })
            .then(function(data) {
              document.getElementById('nlp-result').textContent = JSON.stringify(data, null, 2);
            })
            .catch(function(e) { document.getElementById('nlp-result').textContent = 'Error: ' + e.message; });
          }

          function getText() { return document.getElementById('nlp-text-input').value; }

          var actions = {
            'nlp-full-btn': '/api/ai/nlp/analyze',
            'nlp-entities-btn': '/api/ai/nlp/entities',
            'nlp-sentiment-btn': '/api/ai/nlp/sentiment',
            'nlp-language-btn': '/api/ai/nlp/language',
            'nlp-pii-btn': '/api/ai/nlp/pii'
          };

          Object.keys(actions).forEach(function(id) {
            var el = document.getElementById(id);
            if (el) el.addEventListener('click', function() { nlpCall(actions[id], { text: getText() }); });
          });

          var deviceBtn = document.getElementById('nlp-device-btn');
          if (deviceBtn) {
            deviceBtn.addEventListener('click', function() {
              var deviceId = document.getElementById('nlp-device-select').value;
              var limit = document.getElementById('nlp-limit').value;
              fetch('/api/ai/nlp/device_messages/' + deviceId + '?limit=' + limit)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                  document.getElementById('nlp-result').textContent = JSON.stringify(data, null, 2);
                });
            });
          }
        });
      JS
    end

    style do
      raw <<~CSS
        .nlp-section { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
        .nlp-section h3 { color: #e2e8f0; margin-top: 0; }
        .nlp-actions { display: flex; flex-wrap: wrap; gap: 8px; }
        .nlp-device-controls { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
        .nlp-device-controls label { color: #94a3b8; font-weight: 600; }
        .nlp-device-controls select { background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 6px 10px; }
        .button { background: #3b82f6; color: white; border: none; border-radius: 4px; padding: 8px 16px; cursor: pointer; font-weight: 600; }
        .button:hover { background: #2563eb; }
      CSS
    end
  end
end
