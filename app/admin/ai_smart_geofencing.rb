ActiveAdmin.register_page "Smart Geofencing" do
  menu label: "🗺️ Smart Geofencing", parent: "🧠 AI", priority: 6

  content title: "🗺️ AI Smart Geofencing" do
    devices = Smartphone.all

    if devices.empty?
      div class: "empty-state" do
        h2 "No Devices Available"
        para "Connect a device to use smart geofencing."
      end
    else
      div class: "geofencing-controls" do
        label "Device:", for: "geo-device-select"
        select id: "geo-device-select", class: "device-select-dropdown" do
          devices.each do |device|
            option(value: device.id) { "#{device.name} (#{device.device_id})" }
          end
        end

        button "🏠 Detect Places", id: "detect-places-btn", class: "button", style: "margin-left: 16px;"
        button "💡 Suggest Geofences", id: "suggest-btn", class: "button"
        button "🛤️ Route Predictions", id: "routes-btn", class: "button"
        button "⚠️ Anomalies", id: "anomalies-btn", class: "button"
      end

      div class: "geofencing-grid" do
        div class: "geo-card" do
          h3 "🏠 Detected Places"
          div id: "detected-places", class: "card-content" do
            para "Click a button above to analyze.", class: "placeholder"
          end
        end

        div class: "geo-card" do
          h3 "💡 Suggested Geofences"
          div id: "suggested-geofences", class: "card-content" do
            para "Click a button above to analyze.", class: "placeholder"
          end
        end

        div class: "geo-card" do
          h3 "🛤️ Route Predictions"
          div id: "route-predictions", class: "card-content" do
            para "Click a button above to analyze.", class: "placeholder"
          end
        end

        div class: "geo-card" do
          h3 "⚠️ Route Anomalies"
          div id: "route-anomalies", class: "card-content" do
            para "Click a button above to analyze.", class: "placeholder"
          end
        end
      end
    end

    script do
      text_node <<~JS.html_safe
        document.addEventListener('DOMContentLoaded', function() {
          function geoFetch(endpoint, targetId) {
            var deviceId = document.getElementById('geo-device-select').value;
            fetch('/api/ai/geofencing/' + deviceId + '/' + endpoint)
              .then(function(r) { return r.json(); })
              .then(function(data) {
                document.getElementById(targetId).innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
              })
              .catch(function(e) { document.getElementById(targetId).innerHTML = '<p style="color:#ef4444;">Error: ' + e.message + '</p>'; });
          }

          var btns = {
            'detect-places-btn': ['places', 'detected-places'],
            'suggest-btn': ['suggestions', 'suggested-geofences'],
            'routes-btn': ['routes', 'route-predictions'],
            'anomalies-btn': ['anomalies', 'route-anomalies']
          };

          Object.keys(btns).forEach(function(id) {
            var el = document.getElementById(id);
            if (el) el.addEventListener('click', function() { geoFetch(btns[id][0], btns[id][1]); });
          });
        });
      JS
    end

    style do
      raw <<~CSS
        .geofencing-controls { background: #1e293b; padding: 16px; border-radius: 8px; margin-bottom: 16px; display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
        .geofencing-controls label { color: #94a3b8; font-weight: 600; }
        .geofencing-controls select { background: #334155; color: #e2e8f0; border: 1px solid #475569; border-radius: 4px; padding: 6px 10px; }
        .geofencing-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 16px; }
        .geo-card { background: #1e293b; border-radius: 8px; padding: 16px; }
        .geo-card h3 { color: #e2e8f0; margin-top: 0; border-bottom: 1px solid #334155; padding-bottom: 8px; }
        .card-content pre { color: #94a3b8; white-space: pre-wrap; font-size: 0.85em; max-height: 300px; overflow: auto; }
        .placeholder { color: #64748b; font-style: italic; }
        .button { background: #10b981; color: white; border: none; border-radius: 4px; padding: 8px 16px; cursor: pointer; font-weight: 600; }
        .button:hover { background: #059669; }
      CSS
    end
  end
end
