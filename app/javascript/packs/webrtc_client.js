/**
 * WebRTC Client for Live Streaming
 * Handles peer connection, signaling, and media stream management
 */

const DEBUG = false;
function debugLog(...args) {
  if (DEBUG) console.log(...args);
}

class WebRTCClient {
  constructor(deviceId) {
    this.deviceId = deviceId;
    this.peerConnection = null;
    this.signalingChannel = null;
    this.remoteStream = null;
    this.isStreaming = false;

    // WebRTC Configuration
    this.config = {
      iceServers: [
        { urls: ['stun:stun.l.google.com:19302'] },
        { urls: ['stun:stun1.l.google.com:19302'] },
        { urls: ['stun:stun2.l.google.com:19302'] }
      ]
    };

    this.initialize();
  }

  initialize() {
    debugLog('[WebRTC] Initializing WebRTC client for device:', this.deviceId);
    
    // Setup event listeners
    this.setupEventListeners();
    
    // Initialize signaling channel
    this.initializeSignalingChannel();
  }

  initializeSignalingChannel() {
    debugLog('[WebRTC] Initializing signaling channel');
    
    // Connect via ActionCable to SignalingChannel
    this.signalingChannel = App.cable.subscriptions.create(
      {
        channel: 'SignalingChannel',
        device_id: this.deviceId,
        is_admin: 'true'
      },
      {
        connected: () => {
          debugLog('[WebRTC] Signaling channel connected');
          this.updateStatusUI('Connected');
        },
        disconnected: () => {
          debugLog('[WebRTC] Signaling channel disconnected');
          this.updateStatusUI('Disconnected');
        },
        received: (data) => {
          this.handleSignalingMessage(data);
        }
      }
    );
  }

  setupEventListeners() {
    this.startHandler = () => this.startStream();
    this.stopHandler = () => this.stopStream();
    this.fullScreenHandler = () => this.toggleFullScreen();

    const startBtn = document.getElementById('start-stream-btn');
    const stopBtn = document.getElementById('stop-stream-btn');
    const fullScreenBtn = document.getElementById('full-screen-btn');

    if (startBtn) startBtn.addEventListener('click', this.startHandler);
    if (stopBtn) stopBtn.addEventListener('click', this.stopHandler);
    if (fullScreenBtn) fullScreenBtn.addEventListener('click', this.fullScreenHandler);
  }

  async startStream() {
    if (this.isStreaming) {
      return;
    }

    debugLog('[WebRTC] Starting stream for device:', this.deviceId);
    
    try {
      // Show loading spinner
      this.showLoadingSpinner(true);
      this.updateStatusUI('Initiating...');

      // Create peer connection
      this.createPeerConnection();

      // Send signal to device to start streaming
      this.signalingChannel.send({
        type: 'start_stream',
        device_id: this.deviceId,
        stream_type: 'camera'
      });

      this.isStreaming = true;
      
      // Update button states
      this.updateButtonStates();
      
      debugLog('[WebRTC] Stream start request sent to device');
    } catch (error) {
      console.error('[WebRTC] Error starting stream:', error);
      this.updateStatusUI('Error: ' + error.message);
      this.showLoadingSpinner(false);
    }
  }

  stopStream() {
    debugLog('[WebRTC] Stopping stream');
    
    try {
      // Send stop signal to device
      this.signalingChannel.send({
        type: 'stop_stream',
        device_id: this.deviceId
      });

      this.closeConnection();
      this.isStreaming = false;
      this.updateButtonStates();
      this.updateStatusUI('Stopped');
      
      debugLog('[WebRTC] Stream stopped');
    } catch (error) {
      console.error('[WebRTC] Error stopping stream:', error);
    }
  }

  createPeerConnection() {
    debugLog('[WebRTC] Creating peer connection');

    try {
      this.peerConnection = new RTCPeerConnection({
        iceServers: this.config.iceServers
      });

      // Handle remote stream
      this.peerConnection.ontrack = (event) => {
        debugLog('[WebRTC] Received remote track:', event.track.kind);
        this.handleRemoteTrack(event);
      };

      // Handle ICE candidates
      this.peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
          debugLog('[WebRTC] Generated ICE candidate');
          this.sendSignalingMessage({
            type: 'ice_candidate',
            device_id: this.deviceId,
            target: 'device',
            candidate: event.candidate
          });
        }
      };

      // Handle connection state changes
      this.peerConnection.onconnectionstatechange = () => {
        debugLog('[WebRTC] Connection state:', this.peerConnection.connectionState);
        this.updateStatusUI(this.peerConnection.connectionState);
      };

      // Handle ICE connection state changes
      this.peerConnection.oniceconnectionstatechange = () => {
        debugLog('[WebRTC] ICE connection state:', this.peerConnection.iceConnectionState);
      };

      debugLog('[WebRTC] Peer connection created successfully');
    } catch (error) {
      console.error('[WebRTC] Error creating peer connection:', error);
      throw error;
    }
  }

  async handleSignalingMessage(message) {
    debugLog('[WebRTC] Received signaling message:', message.type);

    try {
      switch (message.type) {
        case 'offer':
          await this.handleOffer(message);
          break;
        case 'answer':
          await this.handleAnswer(message);
          break;
        case 'ice_candidate':
          await this.handleIceCandidate(message);
          break;
        case 'error':
          console.error('[WebRTC] Device error:', message.error);
          this.updateStatusUI('Error: ' + message.error);
          break;
        default:
          debugLog('[WebRTC] Unknown message type:', message.type);
      }
    } catch (error) {
      console.error('[WebRTC] Error handling signaling message:', error);
    }
  }

  async handleOffer(message) {
    debugLog('[WebRTC] Handling offer from device');

    if (!this.peerConnection) {
      this.createPeerConnection();
    }

    try {
      const offer = new RTCSessionDescription({
        type: 'offer',
        sdp: message.sdp
      });

      await this.peerConnection.setRemoteDescription(offer);
      debugLog('[WebRTC] Remote description set (offer)');

      // Create and send answer
      const answer = await this.peerConnection.createAnswer();
      await this.peerConnection.setLocalDescription(answer);
      debugLog('[WebRTC] Local description set (answer)');

      this.sendSignalingMessage({
        type: 'answer',
        device_id: this.deviceId,
        sdp: this.peerConnection.localDescription.sdp
      });

      this.showLoadingSpinner(false);
      this.updateStatusUI('Connected');
    } catch (error) {
      console.error('[WebRTC] Error handling offer:', error);
      throw error;
    }
  }

  async handleAnswer(message) {
    debugLog('[WebRTC] Handling answer from device');

    try {
      const answer = new RTCSessionDescription({
        type: 'answer',
        sdp: message.sdp
      });

      await this.peerConnection.setRemoteDescription(answer);
      debugLog('[WebRTC] Remote description set (answer)');

      this.showLoadingSpinner(false);
      this.updateStatusUI('Connected');
    } catch (error) {
      console.error('[WebRTC] Error handling answer:', error);
    }
  }

  async handleIceCandidate(message) {
    if (!this.peerConnection) {
      return;
    }

    try {
      if (message.candidate && message.candidate.candidate) {
        const candidate = new RTCIceCandidate({
          candidate: message.candidate.candidate,
          sdpMLineIndex: message.candidate.sdpMLineIndex,
          sdpMid: message.candidate.sdpMid
        });

        await this.peerConnection.addIceCandidate(candidate);
        debugLog('[WebRTC] Added ICE candidate');
      }
    } catch (error) {
      console.error('[WebRTC] Error adding ICE candidate:', error);
    }
  }

  handleRemoteTrack(event) {
    debugLog('[WebRTC] Handling remote track:', event.track.kind);

    if (event.streams && event.streams[0]) {
      this.remoteStream = event.streams[0];
      const videoElement = document.getElementById('remoteVideo');
      
      if (videoElement) {
        videoElement.srcObject = this.remoteStream;
        debugLog('[WebRTC] Remote stream attached to video element');
      }

      // Start monitoring connection stats
      this.startStatsMonitoring();
    }
  }

  sendSignalingMessage(message) {
    if (this.signalingChannel) {
      this.signalingChannel.send(message);
      debugLog('[WebRTC] Sent signaling message:', message.type);
    } else {
      console.error('[WebRTC] Signaling channel not available');
    }
  }

  startStatsMonitoring() {
    debugLog('[WebRTC] Starting connection stats monitoring');

    // Show stats panel
    const statsPanel = document.getElementById('connection-stats');
    if (statsPanel) {
      statsPanel.style.display = 'block';
    }

    // Clear previous interval if exists
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
    }

    this.statsInterval = setInterval(async () => {
      if (!this.peerConnection) return;

      try {
        const stats = await this.peerConnection.getStats();
        let bytesReceived = 0;
        let packetsReceived = 0;

        stats.forEach((report) => {
          if (report.type === 'inbound-rtp' && report.kind === 'video') {
            bytesReceived = report.bytesReceived || 0;
            packetsReceived = report.packetsReceived || 0;
          }
        });

        // Update UI
        const bytesReceivedEl = document.getElementById('bytes-received');
        const packetsReceivedEl = document.getElementById('packets-received');

        if (bytesReceivedEl) {
          bytesReceivedEl.textContent = this.formatBytes(bytesReceived);
        }
        if (packetsReceivedEl) {
          packetsReceivedEl.textContent = packetsReceived.toLocaleString();
        }
      } catch (error) {
        console.error('[WebRTC] Error getting stats:', error);
      }
    }, 1000);
  }

  closeConnection() {
    debugLog('[WebRTC] Closing connection');

    // Remove event listeners to prevent memory leaks
    const startBtn = document.getElementById('start-stream-btn');
    const stopBtn = document.getElementById('stop-stream-btn');
    const fullScreenBtn = document.getElementById('full-screen-btn');

    if (startBtn && this.startHandler) startBtn.removeEventListener('click', this.startHandler);
    if (stopBtn && this.stopHandler) stopBtn.removeEventListener('click', this.stopHandler);
    if (fullScreenBtn && this.fullScreenHandler) fullScreenBtn.removeEventListener('click', this.fullScreenHandler);

    // Stop stats monitoring
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
      this.statsInterval = null;
    }

    // Close peer connection
    if (this.peerConnection) {
      // Close all tracks
      if (this.remoteStream) {
        this.remoteStream.getTracks().forEach((track) => {
          track.stop();
        });
      }

      this.peerConnection.close();
      this.peerConnection = null;
      debugLog('[WebRTC] Peer connection closed');
    }

    // Clear video element
    const videoElement = document.getElementById('remoteVideo');
    if (videoElement) {
      videoElement.srcObject = null;
    }

    // Hide stats panel
    const statsPanel = document.getElementById('connection-stats');
    if (statsPanel) {
      statsPanel.style.display = 'none';
    }
  }

  toggleFullScreen() {
    const videoElement = document.getElementById('remoteVideo');
    
    if (!videoElement) return;

    if (!document.fullscreenElement) {
      videoElement.requestFullscreen().catch((error) => {
        console.error('[WebRTC] Fullscreen error:', error);
      });
    } else {
      document.exitFullscreen();
    }
  }

  updateStatusUI(status) {
    const statusElement = document.getElementById('stream-status');
    if (statusElement) {
      statusElement.textContent = status;
      
      // Update badge color based on status
      statusElement.className = 'badge';
      if (status === 'Connected') {
        statusElement.classList.add('badge-success');
      } else if (status === 'Disconnected') {
        statusElement.classList.add('badge-danger');
      } else {
        statusElement.classList.add('badge-warning');
      }
    }
  }

  updateButtonStates() {
    const startBtn = document.getElementById('start-stream-btn');
    const stopBtn = document.getElementById('stop-stream-btn');

    if (startBtn && stopBtn) {
      startBtn.disabled = this.isStreaming;
      stopBtn.disabled = !this.isStreaming;
    }
  }

  showLoadingSpinner(show) {
    const spinner = document.getElementById('loading-spinner');
    if (spinner) {
      spinner.style.display = show ? 'block' : 'none';
    }
  }

  formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
}

// Initialize WebRTC client when page loads
document.addEventListener('DOMContentLoaded', () => {
  if (window.webrtcState && window.webrtcState.deviceId) {
    window.webrtcClient = new WebRTCClient(window.webrtcState.deviceId);
    debugLog('[WebRTC] Client initialized');
  }
});
