# frozen_string_literal: true

module Api
  class SecurityAnalysisController < Api::BaseController
    include ErrorHandler
    include ResponseFormatter

    # GET /api/devices/:id/security/gps_analysis
    def gps_analysis
      smartphone = find_smartphone
      return head :not_found unless smartphone

      result = GpsSpoofingDetector.call(
        smartphone,
        latitude: params[:latitude],
        longitude: params[:longitude],
        accuracy: params[:accuracy],
        provider: params[:provider],
        installed_apps: params[:installed_apps]
      )

      if result.success?
        render json: { status: 'ok', data: result.value }
      else
        render json: { status: 'error', message: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/devices/:id/security/media_analysis
    def media_analysis
      smartphone = find_smartphone
      return head :not_found unless smartphone

      result = DeepfakeDetectionService.call(
        smartphone,
        analysis_type: :media,
        data: {
          file_path: params[:file_path],
          file_size: params[:file_size],
          mime_type: params[:mime_type],
          exif_data: params[:exif_data]&.permit!&.to_h
        }
      )

      if result.success?
        render json: { status: 'ok', data: result.value }
      else
        render json: { status: 'error', message: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/devices/:id/security/tamper_status
    def tamper_status
      smartphone = find_smartphone
      return head :not_found unless smartphone

      result = DeepfakeDetectionService.call(
        smartphone,
        analysis_type: :tamper,
        data: {
          app_signature: params[:app_signature],
          is_debuggable: ActiveModel::Type::Boolean.new.cast(params[:is_debuggable]),
          is_rooted: ActiveModel::Type::Boolean.new.cast(params[:is_rooted]),
          installer_package: params[:installer_package],
          build_type: params[:build_type]
        }
      )

      if result.success?
        render json: { status: 'ok', data: result.value }
      else
        render json: { status: 'error', message: result.error }, status: :unprocessable_entity
      end
    end

    private

    def find_smartphone
      device_id = sanitize_device_id(params[:id])
      Smartphone.find_by(device_id: device_id)
    end
  end
end
