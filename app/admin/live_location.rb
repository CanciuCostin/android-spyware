ActiveAdmin.register_page "Live Location" do
  menu priority: 2, label: "📍 Live Location", parent: "👁 Surveillance"

  content do
    smartphones = Smartphone.all

    panel "Real-Time GPS Tracking" do
      div class: "location-container" do
        div class: "device-selector" do
          h4 "Select Device to Track"
          select id: "location-device-select", class: "location-select" do
            option "-- Select Device --", value: ""
            smartphones.each do |phone|
              option "#{phone.name} (ID: #{phone.id})", value: phone.id
            end
          end
          
          span style: "margin-left: 20px;" do
            button "▶️ Start Tracking", id: "btn-start-tracking", class: "track-btn start-btn", disabled: true
            button "⏹️ Stop Tracking", id: "btn-stop-tracking", class: "track-btn stop-btn", disabled: true
          end
        end

        div class: "location-info", style: "margin-top: 20px; padding: 15px; background: #161b22; border-radius: 8px; display: inline-block;" do
          table do
            tr do
              td { strong "Latitude:" }
              td id: "loc-lat" do "N/A" end
            end
            tr do
              td { strong "Longitude:" }
              td id: "loc-lng" do "N/A" end
            end
            tr do
              td { strong "Accuracy:" }
              td id: "loc-accuracy" do "N/A" end
            end
            tr do
              td { strong "Speed:" }
              td id: "loc-speed" do "N/A" end
            end
            tr do
              td { strong "Last Update:" }
              td id: "loc-timestamp" do "N/A" end
            end
          end
        end

        div id: "live-map", style: "margin-top: 30px; width: 100%; height: 500px; border: 2px solid #00ff00; border-radius: 10px;"
      end
    end

    # Google Maps + ActionCable Integration
    script do
      raw <<-JS
        document.addEventListener('DOMContentLoaded', function() {
          const deviceSelect = document.getElementById('location-device-select');
          const btnStart = document.getElementById('btn-start-tracking');
          const btnStop = document.getElementById('btn-stop-tracking');
          
          if (!deviceSelect) { console.warn('Live location: DOM elements missing'); return; }
          
          let map = null;
          let marker = null;
          let pathLine = null;
          let pathCoords = [];
          let cable = null;
          let locationChannel = null;
          let currentDeviceId = null;

          // Initialize Google Map
          window.initLiveMap = function() {
            map = new google.maps.Map(document.getElementById('live-map'), {
              zoom: 15,
              center: { lat: 42.6977, lng: 23.3219 }, // Sofia, Bulgaria default
              styles: [
                { elementType: "geometry", stylers: [{ color: "#242f3e" }] },
                { elementType: "labels.text.stroke", stylers: [{ color: "#242f3e" }] },
                { elementType: "labels.text.fill", stylers: [{ color: "#746855" }] },
                { featureType: "road", elementType: "geometry", stylers: [{ color: "#38414e" }] },
                { featureType: "water", elementType: "geometry", stylers: [{ color: "#17263c" }] }
              ]
            });

            marker = new google.maps.Marker({
              map: map,
              icon: {
                path: google.maps.SymbolPath.CIRCLE,
                scale: 12,
                fillColor: '#00ff00',
                fillOpacity: 1,
                strokeColor: '#fff',
                strokeWeight: 2
              }
            });

            pathLine = new google.maps.Polyline({
              map: map,
              strokeColor: '#00ff00',
              strokeOpacity: 0.8,
              strokeWeight: 3
            });
          };

          // Enable buttons on device select
          deviceSelect.addEventListener('change', function() {
            currentDeviceId = this.value;
            btnStart.disabled = !currentDeviceId;
          });

          // Connect to LocationChannel
          function startTracking() {
            if (!currentDeviceId) return;

            if (typeof ActionCable === 'undefined') {
              console.error('ActionCable is not loaded');
              return;
            }
            cable = ActionCable.createConsumer();
            locationChannel = cable.subscriptions.create(
              { channel: 'LocationChannel', device_id: currentDeviceId },
              {
                connected() {
                  console.log('Connected to LocationChannel');
                  this.perform('watch_device', { device_id: currentDeviceId, interval: 5000 });
                },
                received(data) {
                  if (data.type === 'location_update') {
                    updateLocation(data);
                  }
                }
              }
            );

            if (btnStart) btnStart.disabled = true;
            if (btnStop) btnStop.disabled = false;
          }

          function stopTracking() {
            if (locationChannel) {
              locationChannel.perform('stop_watching', { device_id: currentDeviceId });
            }
            if (cable) {
              cable.disconnect();
            }
            if (btnStart) btnStart.disabled = false;
            if (btnStop) btnStop.disabled = true;
          }

          function updateLocation(data) {
            const pos = { lat: parseFloat(data.lat), lng: parseFloat(data.lng) };
            
            // Update marker
            if (marker) marker.setPosition(pos);
            if (map) map.panTo(pos);

            // Update path
            pathCoords.push(pos);
            if (pathLine) pathLine.setPath(pathCoords);

            // Update info panel (safe)
            var el;
            el = document.getElementById('loc-lat'); if (el) el.textContent = data.lat;
            el = document.getElementById('loc-lng'); if (el) el.textContent = data.lng;
            el = document.getElementById('loc-accuracy'); if (el) el.textContent = (data.accuracy || 'N/A') + ' m';
            el = document.getElementById('loc-speed'); if (el) el.textContent = (data.speed || 'N/A') + ' m/s';
            el = document.getElementById('loc-timestamp'); if (el) el.textContent = new Date(data.timestamp * 1000).toLocaleString();
          }

          if (btnStart) btnStart.addEventListener('click', startTracking);
          if (btnStop) btnStop.addEventListener('click', stopTracking);
        });
      JS
    end

    # Load Google Maps API
    maps_key = ENV.fetch('MAPS_API_KEY', '')
    if maps_key.present?
      script src: "https://maps.googleapis.com/maps/api/js?key=#{maps_key}&callback=initLiveMap", async: true, defer: true
    else
      div class: "empty-state" do
        h2 "⚠️ Google Maps API Key Not Configured"
        para "Set MAPS_API_KEY environment variable in docker-compose.yml"
      end
    end
  end
end
