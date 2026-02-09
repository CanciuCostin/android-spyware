module Api
  class GdprController < ApplicationController
    include ErrorHandler
    include ResponseFormatter

    skip_before_action :authenticate_admin_user!, raise: false
    before_action :set_smartphone

    # POST /api/devices/:id/erasure_request
    def erasure_request
      service = ErasureService.new(@smartphone)
      result = service.execute_erasure

      if result.success?
        render_success(result.value, message: 'Data erasure completed successfully')
      else
        render_error(result.error, status: :unprocessable_entity)
      end
    end

    # GET /api/devices/:id/data_export
    def data_export
      service = DataExportService.new(@smartphone)

      if params[:format] == 'zip'
        result = service.export_as_zip
        if result.success?
          send_file result.value, type: 'application/zip', disposition: 'attachment'
        else
          render_error(result.error, status: :unprocessable_entity)
        end
      else
        result = service.export_as_json
        if result.success?
          send_data result.value.to_json,
                    filename: "gdpr_export_#{@smartphone.device_id}_#{Date.today}.json",
                    type: 'application/json'
        else
          render_error(result.error, status: :unprocessable_entity)
        end
      end
    end

    # GET /api/devices/:id/retention_policy
    def show_retention_policy
      service = DataRetentionService.new(smartphone: @smartphone)
      render_success(service.current_policy)
    end

    # PUT /api/devices/:id/retention_policy
    def update_retention_policy
      unless params[:policies].is_a?(ActionController::Parameters) || params[:policies].is_a?(Hash)
        return render_error('Missing policies parameter', status: :bad_request)
      end

      service = DataRetentionService.new(smartphone: @smartphone)
      errors = []

      params[:policies].each do |data_type, retention_days|
        result = service.update_policy(data_type, retention_days)
        errors << { data_type: data_type, error: result.error } if result.failure?
      end

      if errors.empty?
        render_success(service.current_policy, message: 'Retention policies updated')
      else
        render_error('Some policies failed to update', status: :unprocessable_entity, details: errors)
      end
    end

    # GET /api/devices/:id/privacy_policy
    def privacy_policy
      device = ApkInstallation.joins(:apk_payload)
                              .find_by(id: @smartphone.apk_installation_id)

      generator = PrivacyPolicyGenerator.new(
        device: device,
        format: params[:format] == 'text' ? :text : :html
      )
      result = generator.generate

      if result.success?
        if params[:format] == 'text'
          render plain: result.value[:content]
        else
          render html: ActionController::Base.helpers.sanitize(result.value[:content]).html_safe
        end
      else
        render_error(result.error, status: :unprocessable_entity)
      end
    end

    private

    def set_smartphone
      @smartphone = Smartphone.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_not_found('Device not found')
    end
  end
end
