module Api
  class GeofenceController < Api::BaseController
    include ErrorHandler
    include ResponseFormatter

    # POST /api/geofence - Receive geofence alert from Android client
    def receive
      device_id = params[:device_id]
      return head :bad_request if device_id.blank?

      smartphone = find_or_create_smartphone(device_id)
      return head :not_found unless smartphone

      # Process location against active geofences
      result = GeofenceService.call(
        smartphone,
        latitude: params[:latitude],
        longitude: params[:longitude]
      )

      # Also cache alert for legacy compatibility
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

    # POST /api/devices/:device_id/geofences
    def create
      smartphone = Smartphone.find_by!(device_id: params[:device_id])
      geofence = smartphone.geofences.build(geofence_params)

      if geofence.save
        render_created(geofence_json(geofence), message: 'Geofence created')
      else
        render_error(geofence.errors.full_messages.join(', '), status: :unprocessable_entity)
      end
    end

    # GET /api/devices/:device_id/geofences
    def index
      smartphone = Smartphone.find_by!(device_id: params[:device_id])
      geofences = smartphone.geofences.order(created_at: :desc)
      geofences = geofences.active if params[:active_only] == 'true'

      render_success(geofences.map { |g| geofence_json(g) })
    end

    # DELETE /api/devices/:device_id/geofences/:id
    def destroy
      smartphone = Smartphone.find_by!(device_id: params[:device_id])
      geofence = smartphone.geofences.find(params[:id])
      geofence.destroy!

      render_success({ id: geofence.id }, message: 'Geofence deleted')
    end

    # GET /api/devices/:device_id/location_history
    def location_history
      smartphone = Smartphone.find_by!(device_id: params[:device_id])

      locations = smartphone.geo_locations.order(created_at: :desc)
      locations = locations.where('created_at >= ?', Time.parse(params[:from])) if params[:from].present?
      locations = locations.where('created_at <= ?', Time.parse(params[:to])) if params[:to].present?
      locations = locations.limit(params[:limit]&.to_i || 500)

      render_success(locations.map { |loc|
        {
          id: loc.id,
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: loc.created_at.iso8601
        }
      })
    end

    # GET /api/devices/:device_id/location_heatmap
    def location_heatmap
      smartphone = Smartphone.find_by!(device_id: params[:device_id])

      days = (params[:days] || 30).to_i.clamp(1, 365)
      locations = smartphone.geo_locations
                            .where('created_at >= ?', days.days.ago)
                            .select(:latitude, :longitude)

      render_success(locations.map { |loc|
        { latitude: loc.latitude, longitude: loc.longitude }
      })
    end

    # GET /api/devices/:device_id/geofence_events
    def events
      smartphone = Smartphone.find_by!(device_id: params[:device_id])

      events = GeofenceEvent.for_device(smartphone.id).recent
      events = events.where(geofence_id: params[:geofence_id]) if params[:geofence_id].present?
      events = events.limit(params[:limit]&.to_i || 100)

      render_success(events.map { |e|
        {
          id: e.id,
          geofence_id: e.geofence_id,
          geofence_name: e.geofence.name,
          event_type: e.event_type,
          latitude: e.lat,
          longitude: e.lng,
          triggered_at: e.triggered_at.iso8601
        }
      })
    end

    private

    def geofence_params
      params.permit(:name, :lat, :lng, :radius_meters, :active,
                     :alert_on_entry, :alert_on_exit, polygon_points: [])
    end

    def geofence_json(geofence)
      {
        id: geofence.id,
        name: geofence.name,
        lat: geofence.lat,
        lng: geofence.lng,
        radius_meters: geofence.radius_meters,
        polygon_points: geofence.polygon_points,
        active: geofence.active,
        alert_on_entry: geofence.alert_on_entry,
        alert_on_exit: geofence.alert_on_exit,
        created_at: geofence.created_at.iso8601
      }
    end
  end
end
