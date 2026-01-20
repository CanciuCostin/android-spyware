ActiveAdmin.register_page "Live Streaming" do
  menu priority: 3, label: "🔴 Live Stream"

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

          let peerConnection = null;
          let cable = null;
          let streamingChannel = null;
          let currentDeviceId = null;

          // Enable buttons when device selected
          deviceSelect.addEventListener('change', function() {
            const hasDevice = this.value !== '';
            btnCamera.disabled = !hasDevice;
            btnMic.disabled = !hasDevice;
            btnBoth.disabled = !hasDevice;
            currentDeviceId = this.value;
          });

          // Initialize ActionCable
          function connectCable(deviceId) {
            cable = ActionCable.createConsumer();
            streamingChannel = cable.subscriptions.create(
              { channel: 'StreamingChannel', device_id: deviceId },
              {
                connected() {
                  statusEl.textContent = 'Status: Connected to signaling server';
                  console.log('Connected to StreamingChannel');
                },
                disconnected() {
                  statusEl.textContent = 'Status: Disconnected';
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
              statusEl.textContent = 'Status: Receiving stream...';
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
              statusEl.textContent = 'Status: 🔴 LIVE';
              remoteVideo.srcObject = event.streams[0];
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
              statusEl.textContent = 'Status: ' + peerConnection.connectionState;
            };
          }

          // Start stream
          async function startStream(type) {
            if (!currentDeviceId) return;
            
            connectCable(currentDeviceId);
            await createPeerConnection();
            
            // Tell device to start streaming
            setTimeout(() => {
              streamingChannel.perform('start_stream', { stream_type: type });
              btnStop.disabled = false;
              btnCamera.disabled = true;
              btnMic.disabled = true;
              btnBoth.disabled = true;
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
            remoteVideo.srcObject = null;
            statusEl.textContent = 'Status: Disconnected';
            btnStop.disabled = true;
            btnCamera.disabled = false;
            btnMic.disabled = false;
            btnBoth.disabled = false;
          }

          btnCamera.addEventListener('click', () => startStream('camera'));
          btnMic.addEventListener('click', () => startStream('microphone'));
          btnBoth.addEventListener('click', () => startStream('both'));
          btnStop.addEventListener('click', stopStream);
        });
      JS
    end
  end
end
