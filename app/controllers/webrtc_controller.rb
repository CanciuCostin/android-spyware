# WebRTC Configuration Controller
class WebrtcController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:turn_credentials]

  # GET /webrtc/turn_credentials
  # Returns TURN server credentials for NAT traversal
  def turn_credentials
    turn_server = ENV.fetch('TURN_SERVER', 'turn:localhost:3478')
    turn_user = ENV.fetch('TURN_USER', 'eaglespy')
    turn_password = ENV.fetch('TURN_PASSWORD', 'eaglespy_secret')

    # Generate time-limited credentials (TURN REST API style)
    ttl = 86400 # 24 hours
    expiry = Time.now.to_i + ttl
    username = "#{expiry}:#{turn_user}"
    
    # HMAC-SHA1 for credential generation
    credential = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha1', turn_password, username)
    )

    render json: {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        {
          urls: turn_server,
          username: username,
          credential: credential
        }
      ],
      iceTransportPolicy: 'all'
    }
  end

  # POST /webrtc/signal
  # Alternative REST-based signaling (if WebSocket unavailable)
  def signal
    device_id = params[:device_id]
    signal_type = params[:signal_type]
    payload = params[:payload]

    case signal_type
    when 'offer'
      ActionCable.server.broadcast("streaming_#{device_id}_admin", { type: 'offer', sdp: payload })
    when 'answer'
      ActionCable.server.broadcast("streaming_#{device_id}", { type: 'answer', sdp: payload })
    when 'ice_candidate'
      target = params[:target] == 'device' ? device_id : "#{device_id}_admin"
      ActionCable.server.broadcast("streaming_#{target}", { type: 'ice_candidate', candidate: payload })
    end

    render json: { status: 'ok' }
  end
end
