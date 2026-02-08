module Api
  class GeofenceController < Api::BaseController

    def receive
      device_id = params[:device_id]
      return head :bad_request if device_id.blank?

      # Store geofence alert
      cache_key = "geofence_alerts:#{device_id}"
      alerts = Rails.cache.read(cache_key) || []
      alerts.unshift({
        transition: params[:transition],
        zones: params[:zones],
        latitude: params[:latitude],
        longitude: params[:longitude],
        timestamp: params[:timestamp],
        received_at: Time.current.iso8601
      })
      alerts = alerts.first(200)
      Rails.cache.write(cache_key, alerts, expires_in: 30.days)

      # Broadcast alert
      ActionCable.server.broadcast("geofence_stream", {
        device_id: device_id,
        transition: params[:transition],
        zones: params[:zones],
        latitude: params[:latitude],
        longitude: params[:longitude],
        timestamp: Time.current.iso8601
      }) rescue nil

      head :ok
    end
  end
end
