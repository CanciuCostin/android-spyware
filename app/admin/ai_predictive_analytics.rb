ActiveAdmin.register_page "Predictive Analytics" do
  menu label: "🔮 Predictions", parent: "🧠 AI", priority: 5

  content title: "🔮 Predictive Analytics" do
    devices = Smartphone.all

    if devices.empty?
      div class: "empty-state" do
        h2 "No Devices Available"
        para "Connect a device to view predictions."
      end
    else
      div class: "prediction-controls" do
        label "Device:", for: "predict-device-select"
        select id: "predict-device-select", class: "device-select-dropdown" do
          devices.each do |device|
            option(value: device.id) { "#{device.name} (#{device.device_id})" }
          end
        end

        label "Days:", for: "predict-days", style: "margin-left: 16px;"
        select id: "predict-days" do
          [7, 14, 30, 60, 90].each do |d|
            option(value: d, selected: d == 30 ? 'selected' : nil) { "#{d} days" }
          end
        end

        button "🔮 Run Predictions", id: "run-predictions-btn", class: "button", style: "margin-left: 16px;"
      end

      # Predictions grid
      div class: "predictions-grid" do
        # Location Prediction
        div class: "prediction-card" do
          h3 "📍 Location Prediction"
          div id: "location-prediction", class: "card-content" do
            para "Click 'Run Predictions' to analyze.", class: "placeholder"
          end
        end

        # Activity Forecast
        div class: "prediction-card" do
          h3 "📈 Activity Forecast"
          div id: "activity-forecast", class: "card-content" do
            para "Click 'Run Predictions' to analyze.", class: "placeholder"
          end
        end

        # Risk Score
        div class: "prediction-card" do
          h3 "🛡️ Risk Score"
          div id: "risk-score-card", class: "card-content" do
            para "Click 'Run Predictions' to analyze.", class: "placeholder"
          end
        end

        # Contact Importance
        div class: "prediction-card" do
          h3 "👥 Contact Importance"
          div id: "contact-importance", class: "card-content" do
            para "Click 'Run Predictions' to analyze.", class: "placeholder"
          end
        end
      end
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          var btn = document.getElementById('run-predictions-btn');
          if (!btn) return;

          btn.addEventListener('click', function() {
            var deviceId = document.getElementById('predict-device-select').value;
            var days = document.getElementById('predict-days').value;

            fetch('/api/ai/predictions/' + deviceId + '?days=' + days)
              .then(function(r) { return r.json(); })
              .then(function(data) {
                var p = data.predictions || {};
                document.getElementById('location-prediction').innerHTML = '<pre>' + JSON.stringify(p.location_prediction, null, 2) + '</pre>';
                document.getElementById('activity-forecast').innerHTML = '<pre>' + JSON.stringify(p.activity_forecast, null, 2) + '</pre>';
                document.getElementById('risk-score-card').innerHTML = '<pre>' + JSON.stringify(p.risk_score, null, 2) + '</pre>';
                document.getElementById('contact-importance').innerHTML = '<pre>' + JSON.stringify(p.contact_importance, null, 2) + '</pre>';
              })
              .catch(function(e) { alert('Error: ' + e.message); });
          });
        });
      JS
    end

    style do
      raw <<~CSS
        .prediction-controls { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
        .prediction-controls label { color: #94a3b8; font-weight: 600; }
        .prediction-controls select { background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 6px 10px; }
        .predictions-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 16px; }
        .prediction-card { background: #1e293b; border-radius: 8px; padding: 16px; }
        .prediction-card h3 { color: #e2e8f0; margin-top: 0; border-bottom: 1px solid #334155; padding-bottom: 8px; }
        .card-content pre { color: #94a3b8; white-space: pre-wrap; font-size: 0.85em; max-height: 300px; overflow: auto; }
        .placeholder { color: #64748b; font-style: italic; }
        .button { background: #8b5cf6; color: white; border: none; border-radius: 4px; padding: 8px 16px; cursor: pointer; font-weight: 600; }
        .button:hover { background: #7c3aed; }
      CSS
    end
  end
end
