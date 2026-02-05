# API Controller for REST-based command polling (fallback for WebSocket)
module Api
  class CommandsController < Api::BaseController
    before_action :authenticate_admin_user!, only: [:send_command]
    skip_before_action :authenticate_device!, only: [:send_command]

    # GET /api/commands/:device_id
    # Android device polls for pending commands
    def show
      device_id = sanitize_device_id(params[:id])
      commands = fetch_pending_commands(device_id)

      render json: { commands: commands }
    end

  # POST /api/commands/:device_id/ack
  # Device acknowledges command execution
    def ack
      device_id = sanitize_device_id(params[:id])
      command_id = params[:command_id]

      mark_command_executed(device_id, command_id)

      render json: { status: 'ok' }
    end

  # POST /api/commands/:device_id/send
  # Admin sends command to device via WebSocket broadcast
    def send_command
      device_id = sanitize_device_id(params[:id])
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
      device_id = sanitize_device_id(request.headers['X-Device-Id'] || params[:device_id])
      smartphone = find_or_create_smartphone(device_id)

      return render json: { error: 'Device not found' }, status: :not_found unless smartphone

      latitude = params[:latitude]
      longitude = params[:longitude]
      unless valid_coordinates?(latitude, longitude)
        return render json: { error: 'Invalid coordinates' }, status: :unprocessable_entity
      end

      timestamp = params[:timestamp]
      formatted_time = if timestamp.present?
        Time.at(timestamp.to_i / 1000).strftime('%Y-%m-%d %H:%M:%S')
      else
        Time.current.strftime('%Y-%m-%d %H:%M:%S')
      end

      GeoLocation.create!(
        smartphone: smartphone,
        lat: params[:latitude],
        long: params[:longitude],
        date: formatted_time
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
      RedisPool.with do |redis|
        commands = redis.lrange("commands:#{device_id}:pending", 0, -1)
        commands.map { |c| JSON.parse(c) }
      end
    rescue StandardError => e
      Rails.logger.warn "[API::CommandsController] Redis error: #{e.message}"
      []
    end

    def mark_command_executed(device_id, command_id)
      RedisPool.with do |redis|
        redis.sadd("commands:#{device_id}:executed", command_id)
      end
    rescue StandardError => e
      Rails.logger.warn "[API::CommandsController] Redis error: #{e.message}"
    end

    def valid_coordinates?(lat, long)
      lat_f = lat.to_f
      long_f = long.to_f
      lat.present? && long.present? && lat_f.between?(-90, 90) && long_f.between?(-180, 180)
    rescue StandardError
      false
    end
end
