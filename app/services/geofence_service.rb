class GeofenceService < ApplicationService
  EARTH_RADIUS_METERS = 6_371_000.0

  def initialize(smartphone, location_data = {})
    @smartphone = smartphone
    @location_data = location_data
  end

  def call
    return Result.failure('Smartphone is required') unless @smartphone
    return Result.failure('Location data is required') unless valid_location?

    lat = @location_data[:latitude].to_f
    lng = @location_data[:longitude].to_f
    events = []

    Geofence.active.for_device(@smartphone.id).find_each do |geofence|
      inside = point_inside_geofence?(lat, lng, geofence)
      was_inside = last_event_was_entry?(geofence)

      if inside && !was_inside && geofence.alert_on_entry
        events << record_event(geofence, 'entry', lat, lng)
      elsif !inside && was_inside && geofence.alert_on_exit
        events << record_event(geofence, 'exit', lat, lng)
      end
    end

    Result.success(events.compact)
  rescue StandardError => e
    Rails.logger.error("[GeofenceService] Error: #{e.message}")
    Result.failure(e.message)
  end

  # Check if a point is inside a geofence (circle or polygon)
  def point_inside_geofence?(lat, lng, geofence)
    if geofence.circle?
      point_in_circle?(lat, lng, geofence.lat, geofence.lng, geofence.radius_meters)
    elsif geofence.polygon?
      point_in_polygon?(lat, lng, geofence.polygon_points)
    else
      false
    end
  end

  # Haversine formula for circle geofences
  def point_in_circle?(lat1, lng1, lat2, lng2, radius_meters)
    haversine_distance(lat1, lng1, lat2, lng2) <= radius_meters
  end

  def haversine_distance(lat1, lng1, lat2, lng2)
    d_lat = to_rad(lat2 - lat1)
    d_lng = to_rad(lng2 - lng1)

    a = Math.sin(d_lat / 2)**2 +
        Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * Math.sin(d_lng / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    EARTH_RADIUS_METERS * c
  end

  # Ray casting algorithm for polygon geofences
  def point_in_polygon?(lat, lng, polygon_points)
    return false unless polygon_points.is_a?(Array) && polygon_points.length >= 3

    n = polygon_points.length
    inside = false

    j = n - 1
    n.times do |i|
      yi = polygon_points[i][1].to_f
      xi = polygon_points[i][0].to_f
      yj = polygon_points[j][1].to_f
      xj = polygon_points[j][0].to_f

      if ((yi > lat) != (yj > lat)) &&
         (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
        inside = !inside
      end

      j = i
    end

    inside
  end

  private

  def valid_location?
    @location_data[:latitude].present? && @location_data[:longitude].present?
  end

  def to_rad(degrees)
    degrees * Math::PI / 180.0
  end

  def last_event_was_entry?(geofence)
    last_event = GeofenceEvent.where(
      smartphone: @smartphone,
      geofence: geofence
    ).order(triggered_at: :desc).first

    last_event&.event_type == 'entry'
  end

  def record_event(geofence, event_type, lat, lng)
    event = GeofenceEvent.create!(
      smartphone: @smartphone,
      geofence: geofence,
      event_type: event_type,
      lat: lat,
      lng: lng,
      triggered_at: Time.current
    )

    broadcast_alert(geofence, event)
    trigger_alert_service(geofence, event)

    event
  rescue StandardError => e
    Rails.logger.error("[GeofenceService] Failed to record event: #{e.message}")
    nil
  end

  def broadcast_alert(geofence, event)
    ActionCable.server.broadcast('geofence_stream', {
      device_id: @smartphone.device_id,
      geofence_id: geofence.id,
      geofence_name: geofence.name,
      transition: event.event_type.upcase,
      latitude: event.lat,
      longitude: event.lng,
      timestamp: event.triggered_at.iso8601
    })
  rescue StandardError => e
    Rails.logger.warn("[GeofenceService] Broadcast failed: #{e.message}")
  end

  def trigger_alert_service(geofence, event)
    AlertService.trigger(
      "geofence_#{event.event_type}",
      @smartphone,
      {
        geofence_name: geofence.name,
        geofence_id: geofence.id,
        latitude: event.lat,
        longitude: event.lng,
        event_type: event.event_type,
        severity: 'high'
      }
    )
  rescue StandardError => e
    Rails.logger.warn("[GeofenceService] Alert trigger failed: #{e.message}")
  end
end
