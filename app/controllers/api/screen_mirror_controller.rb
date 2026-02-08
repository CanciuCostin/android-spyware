# frozen_string_literal: true

module Api
  class ScreenMirrorController < Api::BaseController
    include ErrorHandler if defined?(ErrorHandler)
    include ResponseFormatter if defined?(ResponseFormatter)

    # POST /api/devices/:id/screen/start
    def start
      smartphone = find_smartphone
      return head :not_found unless smartphone
      return render_consent_required unless consent_granted?(smartphone)

      service = ScreenMirroringService.new(
        smartphone,
        admin_user: current_admin_identifier,
        fps: params[:fps],
        quality: params[:quality]
      )

      result = service.start_session

      if result.success?
        render json: { status: 'ok', data: result.value }, status: :ok
      else
        render json: { status: 'error', message: result.error }, status: :unprocessable_entity
      end
    end

    # POST /api/devices/:id/screen/stop
    def stop
      smartphone = find_smartphone
      return head :not_found unless smartphone

      service = ScreenMirroringService.new(smartphone)
      result = service.stop_session

      if result.success?
        render json: { status: 'ok', data: result.value }, status: :ok
      else
        render json: { status: 'error', message: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/devices/:id/screen/status
    def status
      smartphone = find_smartphone
      return head :not_found unless smartphone

      service = ScreenMirroringService.new(smartphone)
      result = service.session_status

      render json: { status: 'ok', data: result.value }, status: :ok
    end

    private

    def find_smartphone
      device_id = sanitize_device_id(params[:id])
      Smartphone.find_by(device_id: device_id) || ApkInstallation.find_by(device_id: device_id)
    end

    def consent_granted?(device)
      ConsentService.new(device).check_consent('device_monitoring')
    end

    def current_admin_identifier
      current_admin_user&.email rescue 'api_client'
    end

    def render_consent_required
      render json: {
        status: 'error',
        error_code: 'CONSENT_REQUIRED',
        message: 'Device monitoring consent has not been granted. Screen mirroring requires explicit device_monitoring consent (GDPR Art. 5, 7).'
      }, status: :forbidden
    end
  end
end
