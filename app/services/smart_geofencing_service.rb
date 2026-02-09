# frozen_string_literal: true

class SmartGeofencingService < ApplicationService
  CLUSTER_RADIUS_KM = 0.3
  MIN_VISITS_FOR_SUGGESTION = 3
  HOME_HOURS = (21..23).to_a + (0..6).to_a
  WORK_HOURS = (9..17).to_a

  def initialize(device, options = {})
    @device = device
    @days = options[:days] || 30
    @start_date = options[:start_date] || @days.days.ago
  end

  def call
    return Result.failure('Device is required') unless @device

    Result.success(
      detected_places: detect_places,
      suggested_geofences: suggest_geofences,
      route_predictions: predict_routes,
      route_anomalies: detect_route_anomalies
    )
  rescue StandardError => e
    Rails.logger.error("[SmartGeofencingService] #{e.message}")
    Result.failure(e.message)
  end

  # --- Place Detection (Home/Work) ---

  def detect_places
    locations = load_locations
    return { home: nil, work: nil, message: 'Insufficient location data' } if locations.size < 10

    home_candidates = locations.select { |l| HOME_HOURS.include?(l[:hour]) }
    work_candidates = locations.select { |l| WORK_HOURS.include?(l[:hour]) }

    home = largest_cluster(home_candidates)
    work = largest_cluster(work_candidates)

    {
      home: home ? { latitude: home[:lat], longitude: home[:lng], confidence: home[:confidence], visits: home[:count] } : nil,
      work: work ? { latitude: work[:lat], longitude: work[:lng], confidence: work[:confidence], visits: work[:count] } : nil,
      data_points: locations.size
    }
  rescue StandardError => e
    { home: nil, work: nil, error: e.message }
  end

  # --- Geofence Suggestions ---

  def suggest_geofences
    locations = load_locations
    clusters = find_clusters(locations)

    clusters
      .select { |c| c[:count] >= MIN_VISITS_FOR_SUGGESTION }
      .sort_by { |c| -c[:count] }
      .first(10)
      .map.with_index do |cluster, i|
        label = label_for_cluster(cluster)
        {
          name: "#{label} ##{i + 1}",
          latitude: cluster[:lat],
          longitude: cluster[:lng],
          radius_meters: suggested_radius(cluster),
          visits: cluster[:count],
          confidence: cluster[:confidence],
          peak_hours: cluster[:peak_hours],
          type: label.downcase
        }
      end
  rescue StandardError => e
    Rails.logger.error("[SmartGeofencingService] Suggestion error: #{e.message}")
    []
  end

  # --- Route Prediction ---

  def predict_routes
    current_hour = Time.current.hour
    current_dow = Time.current.wday

    # Find typical movement patterns for this time/day
    transitions = daily_transitions(current_dow)
    return { routes: [], message: 'Insufficient data for route prediction' } if transitions.size < 3

    upcoming = transitions.select { |t| t[:hour] >= current_hour }.first(3)

    {
      predicted_movements: upcoming.map do |t|
        {
          from: { latitude: t[:from_lat], longitude: t[:from_lng] },
          to: { latitude: t[:to_lat], longitude: t[:to_lng] },
          expected_hour: t[:hour],
          confidence: t[:confidence]
        }
      end,
      based_on_weeks: (@days / 7.0).ceil
    }
  rescue StandardError => e
    { routes: [], error: e.message }
  end

  # --- Route Anomaly Detection ---

  def detect_route_anomalies
    today_locations = @device.geo_locations
                             .where(created_at: Time.current.beginning_of_day..Time.current)
                             .order(:created_at)
                             .pluck(:latitude, :longitude, :created_at)

    return { anomalies: [], message: 'No location data today' } if today_locations.size < 2

    anomalies = []

    # Check for unusual speed
    today_locations.each_cons(2) do |(lat1, lng1, t1), (lat2, lng2, t2)|
      dist_km = haversine_km(lat1.to_f, lng1.to_f, lat2.to_f, lng2.to_f)
      hours = (t2 - t1) / 3600.0
      next if hours <= 0

      speed_kmh = dist_km / hours
      if speed_kmh > 200
        anomalies << {
          type: 'unusual_speed',
          speed_kmh: speed_kmh.round(1),
          from: { lat: lat1.to_f, lng: lng1.to_f },
          to: { lat: lat2.to_f, lng: lng2.to_f },
          at: t2.iso8601,
          severity: speed_kmh > 500 ? 'high' : 'medium'
        }
      end
    end

    # Check if current location is unusual for this time
    places = detect_places
    current = today_locations.last
    if current && places[:home] && places[:work]
      expected = if HOME_HOURS.include?(Time.current.hour)
                   places[:home]
                 elsif WORK_HOURS.include?(Time.current.hour)
                   places[:work]
                 end

      if expected
        dist = haversine_km(current[0].to_f, current[1].to_f, expected[:latitude], expected[:longitude])
        if dist > 10
          anomalies << {
            type: 'unexpected_location',
            expected_place: HOME_HOURS.include?(Time.current.hour) ? 'home' : 'work',
            distance_from_expected_km: dist.round(2),
            current: { lat: current[0].to_f, lng: current[1].to_f },
            severity: dist > 50 ? 'high' : 'medium'
          }
        end
      end
    end

    { anomalies: anomalies, checked_at: Time.current.iso8601 }
  rescue StandardError => e
    { anomalies: [], error: e.message }
  end

  private

  def load_locations
    @device.geo_locations
           .where('created_at >= ?', @start_date)
           .order(:created_at)
           .pluck(:latitude, :longitude, :created_at)
           .map { |lat, lng, ts| { lat: lat.to_f, lng: lng.to_f, hour: ts.hour, dow: ts.wday, time: ts } }
  rescue StandardError
    []
  end

  def find_clusters(points)
    return [] if points.empty?

    used = Array.new(points.size, false)
    clusters = []

    points.each_with_index do |point, i|
      next if used[i]

      members = []
      points.each_with_index do |p, j|
        next if used[j]
        if haversine_km(point[:lat], point[:lng], p[:lat], p[:lng]) <= CLUSTER_RADIUS_KM
          members << p
          used[j] = true
        end
      end

      next if members.empty?

      avg_lat = members.sum { |m| m[:lat] } / members.size
      avg_lng = members.sum { |m| m[:lng] } / members.size
      hours = members.map { |m| m[:hour] }
      peak = hours.tally.max_by { |_, v| v }&.first

      clusters << {
        lat: avg_lat.round(6),
        lng: avg_lng.round(6),
        count: members.size,
        confidence: (members.size.to_f / points.size * 100).round(1),
        peak_hours: hours.tally.sort_by { |_, v| -v }.first(3).map { |h, c| { hour: h, count: c } },
        hours: hours
      }
    end

    clusters
  end

  def largest_cluster(points)
    clusters = find_clusters(points)
    clusters.max_by { |c| c[:count] }
  end

  def label_for_cluster(cluster)
    hours = cluster[:hours] || []
    home_count = hours.count { |h| HOME_HOURS.include?(h) }
    work_count = hours.count { |h| WORK_HOURS.include?(h) }

    if home_count > work_count * 2
      'Home'
    elsif work_count > home_count * 2
      'Work'
    else
      'Frequent'
    end
  end

  def suggested_radius(cluster)
    case cluster[:count]
    when 0..5    then 500
    when 6..20   then 300
    when 21..50  then 200
    else 150
    end
  end

  def daily_transitions(dow)
    # Get all locations for the given day of week
    locations = load_locations.select { |l| l[:dow] == dow }.sort_by { |l| l[:time] }
    return [] if locations.size < 2

    transitions = []
    locations.each_cons(2) do |from, to|
      dist = haversine_km(from[:lat], from[:lng], to[:lat], to[:lng])
      next if dist < 0.5 # Skip minor movements

      transitions << {
        from_lat: from[:lat], from_lng: from[:lng],
        to_lat: to[:lat], to_lng: to[:lng],
        hour: to[:hour],
        distance_km: dist.round(2),
        confidence: 50 # Baseline; would improve with more data
      }
    end

    # Group by hour and pick most common
    transitions.group_by { |t| t[:hour] }.map do |hour, ts|
      most_common = ts.max_by { |t| ts.count { |o| haversine_km(t[:to_lat], t[:to_lng], o[:to_lat], o[:to_lng]) < 1 } }
      most_common[:confidence] = (ts.size.to_f / (@days / 7.0).ceil * 100).clamp(0, 100).round(1)
      most_common
    end.sort_by { |t| t[:hour] }
  rescue StandardError
    []
  end

  def haversine_km(lat1, lng1, lat2, lng2)
    r = 6371.0
    d_lat = (lat2 - lat1) * Math::PI / 180
    d_lng = (lng2 - lng1) * Math::PI / 180
    a = Math.sin(d_lat / 2)**2 + Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(d_lng / 2)**2
    r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end
end
