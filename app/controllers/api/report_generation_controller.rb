# frozen_string_literal: true

module Api
  class ReportGenerationController < Api::BaseController
    skip_before_action :authenticate_device!

    # POST /api/ai/reports/generate
    def generate
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = ReportGenerationService.new(device,
        template: params[:template] || 'device_activity',
        format: params[:format] || 'json',
        period: params[:period] || 'weekly',
        start_date: parse_date(params[:start_date]),
        end_date: parse_date(params[:end_date])
      )

      result = service.call
      if result.success?
        if result.value.is_a?(Hash) && result.value[:content_type] == 'text/html'
          send_data result.value[:body],
                    filename: result.value[:filename],
                    type: 'text/html',
                    disposition: 'attachment'
        else
          render json: result.value
        end
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/ai/reports/templates
    def templates
      render json: { templates: ReportGenerationService.available_templates }
    end

    # POST /api/ai/reports/risk_assessment
    def risk_assessment
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = ReportGenerationService.new(device, template: 'security_audit', period: params[:period] || 'weekly')
      result = service.call

      if result.success?
        render json: { device_id: device.device_id, risk_assessment: result.value[:risk_assessment] }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    private

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end

    def parse_date(str)
      return nil if str.blank?
      Time.parse(str)
    rescue ArgumentError
      nil
    end
  end
end
