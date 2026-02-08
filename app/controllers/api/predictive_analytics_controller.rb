# frozen_string_literal: true

module Api
  class PredictiveAnalyticsController < Api::BaseController
    skip_before_action :authenticate_device!

    # GET /api/ai/predictions/:device_id
    def show
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = PredictiveAnalyticsService.new(device, days: (params[:days] || 30).to_i)
      result = service.call

      if result.success?
        render json: { device_id: device.device_id, predictions: result.value }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/ai/predictions/:device_id/location
    def location
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = PredictiveAnalyticsService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, location_prediction: service.predict_next_location }
    end

    # GET /api/ai/predictions/:device_id/activity
    def activity
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = PredictiveAnalyticsService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, activity_forecast: service.forecast_activity }
    end

    # GET /api/ai/predictions/:device_id/risk
    def risk
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = PredictiveAnalyticsService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, risk_score: service.calculate_risk_score }
    end

    # GET /api/ai/predictions/:device_id/contacts
    def contacts
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = PredictiveAnalyticsService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, contact_importance: service.score_contact_importance }
    end

    private

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end
  end
end
