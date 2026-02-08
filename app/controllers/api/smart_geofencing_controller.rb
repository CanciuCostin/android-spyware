# frozen_string_literal: true

module Api
  class SmartGeofencingController < Api::BaseController
    skip_before_action :authenticate_device!

    # GET /api/ai/geofencing/:device_id
    def show
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = SmartGeofencingService.new(device, days: (params[:days] || 30).to_i)
      result = service.call

      if result.success?
        render json: { device_id: device.device_id, smart_geofencing: result.value }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/ai/geofencing/:device_id/places
    def places
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = SmartGeofencingService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, detected_places: service.detect_places }
    end

    # GET /api/ai/geofencing/:device_id/suggestions
    def suggestions
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = SmartGeofencingService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, suggested_geofences: service.suggest_geofences }
    end

    # GET /api/ai/geofencing/:device_id/routes
    def routes
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = SmartGeofencingService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, route_predictions: service.predict_routes }
    end

    # GET /api/ai/geofencing/:device_id/anomalies
    def anomalies
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = SmartGeofencingService.new(device, days: (params[:days] || 30).to_i)
      render json: { device_id: device.device_id, route_anomalies: service.detect_route_anomalies }
    end

    private

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end
  end
end
