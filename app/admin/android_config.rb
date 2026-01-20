ActiveAdmin.register_page "Android Config" do
  menu priority: 4, label: "📱 APK Config"

  content do
    # Get current config from settings or defaults
    config = {
      server_url: ENV['RAILS_HOST'] || '213.91.211.150',
      server_port: ENV['RAILS_PORT'] || '3000',
      turn_server: ENV['TURN_SERVER'] || '213.91.211.150:3478',
      turn_user: ENV['TURN_USER'] || 'eaglespy',
      turn_password: ENV['TURN_PASSWORD'] || 'EagleSpy2024Secure!',
      use_ssl: ENV['USE_SSL'] == 'true'
    }

    panel "🔧 Android Client Configuration" do
      para "Configure the connection settings for the Android APK. These values will be served to the client via API."
      
      render partial: 'admin/android_config/form', locals: { config: config }
    end

    panel "📋 Current Configuration" do
      table_for [config] do
        column("Setting") { |_| "Server URL" }
        column("Value") { |c| config[:use_ssl] ? "wss://#{c[:server_url]}:#{c[:server_port]}/cable" : "ws://#{c[:server_url]}:#{c[:server_port]}/cable" }
      end
      table_for [config] do
        column("Setting") { |_| "TURN Server" }
        column("Value") { |c| "turn:#{c[:turn_server]}" }
      end
      table_for [config] do
        column("Setting") { |_| "TURN Username" }
        column("Value") { |c| c[:turn_user] }
      end
    end

    panel "📲 APK Download" do
      para "Download the pre-configured APK or generate a new one with custom settings."
      
      div class: "apk-actions" do
        if File.exist?(Rails.root.join('public', 'downloads', 'eaglespy.apk'))
          a href: "/downloads/eaglespy.apk", class: "download-btn" do
            "⬇️ Download APK"
          end
        else
          para "No APK available. Build from Android Studio first.", style: "color: #f85149;"
        end
      end
    end

    panel "🧪 Connection Test" do
      div id: "connection-test" do
        button "Test WebSocket Connection", id: "test-ws-btn", class: "test-btn"
        button "Test TURN Server", id: "test-turn-btn", class: "test-btn"
        div id: "test-results", style: "margin-top: 15px; padding: 10px; background: #161b22; border-radius: 5px; font-family: monospace;"
      end
    end

    # JavaScript for testing
    script do
      raw <<-JS
        document.addEventListener('DOMContentLoaded', function() {
          const resultsEl = document.getElementById('test-results');
          
          document.getElementById('test-ws-btn').addEventListener('click', function() {
            resultsEl.innerHTML = '🔄 Testing WebSocket connection...';
            
            const wsUrl = '#{config[:use_ssl] ? 'wss' : 'ws'}://#{config[:server_url]}:#{config[:server_port]}/cable';
            const ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
              resultsEl.innerHTML = '<span style="color: #3fb950;">✅ WebSocket connected successfully!</span><br>URL: ' + wsUrl;
              ws.close();
            };
            
            ws.onerror = function(err) {
              resultsEl.innerHTML = '<span style="color: #f85149;">❌ WebSocket connection failed</span><br>URL: ' + wsUrl + '<br>Check if server is running and port is open.';
            };
            
            setTimeout(function() {
              if (ws.readyState !== WebSocket.OPEN && ws.readyState !== WebSocket.CLOSED) {
                ws.close();
                resultsEl.innerHTML = '<span style="color: #f85149;">❌ Connection timeout</span>';
              }
            }, 5000);
          });
          
          document.getElementById('test-turn-btn').addEventListener('click', function() {
            resultsEl.innerHTML = '🔄 Testing TURN server...';
            
            const config = {
              iceServers: [
                { urls: 'turn:#{config[:turn_server]}', username: '#{config[:turn_user]}', credential: '#{config[:turn_password]}' }
              ]
            };
            
            const pc = new RTCPeerConnection(config);
            let turnWorks = false;
            
            pc.onicecandidate = function(e) {
              if (e.candidate && e.candidate.candidate.indexOf('relay') > -1) {
                turnWorks = true;
                resultsEl.innerHTML = '<span style="color: #3fb950;">✅ TURN server working!</span><br>Relay candidate received.';
                pc.close();
              }
            };
            
            pc.createDataChannel('test');
            pc.createOffer().then(offer => pc.setLocalDescription(offer));
            
            setTimeout(function() {
              if (!turnWorks) {
                resultsEl.innerHTML = '<span style="color: #d29922;">⚠️ TURN server may not be reachable</span><br>No relay candidates received. Check firewall and ports.';
                pc.close();
              }
            }, 5000);
          });
        });
      JS
    end
  end
end
