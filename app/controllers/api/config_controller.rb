# API endpoint for Android client configuration
class Api::ConfigController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /api/config
  # Returns server configuration for Android client
  def show
    config = {
      server_url: build_websocket_url,
      turn_servers: [
        {
          url: "turn:#{ENV['TURN_SERVER'] || '213.91.211.150:3478'}",
          username: ENV['TURN_USER'] || 'eaglespy',
          credential: ENV['TURN_PASSWORD'] || 'EagleSpy2024Secure!'
        }
      ],
      stun_servers: [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302"
      ],
      polling_interval: 15, # minutes
      location_interval: 10, # seconds
      version: "1.0.0"
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
end
