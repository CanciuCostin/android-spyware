# frozen_string_literal: true

class GpsSpoofingDetector < ApplicationService
  # Maximum plausible speed in km/h (commercial aircraft ~900km/h)
  MAX_SPEED_KMH = 900.0
  EARTH_RADIUS_KM = 6371.0

  # Minimum GPS accuracy (meters) below which data is suspicious
  SUSPICIOUS_ACCURACY_THRESHOLD = 1.0

  KNOWN_SPOOF_APPS = DeepfakeDetectionService::KNOWN_SPOOF_APPS

  def initialize(smartphone, location_data = {})
    @smartphone = smartphone
    @location_data = location_data || {}
  end

  def call
    return Result.failure('Smartphone is required') unless @smartphone

    alerts = []

    alerts.concat(check_impossible_travel)
    alerts.concat(check_mock_location_provider)
    alerts.concat(check_gps_accuracy)
    alerts.concat(check_spoofing_apps)

    risk_score = calculate_risk_score(alerts)
    spoofing_detected = risk_score > 50

    Result.success(
      spoofing_detected: spoofing_detected,
      risk_score: risk_score,
      alerts: alerts,
      analyzed_at: Time.current.iso8601
    )
  rescue StandardError => e
    Rails.logger.error("[GpsSpoofingDetector] Error: #{e.message}")
    Result.failure(e.message)
  end

  private

  def check_impossible_travel
    alerts = []
    lat = @location_data[:latitude]&.to_f
    lng = @location_data[:longitude]&.to_f
    return alerts unless lat && lng

    previous = last_known_location
    return alerts unless previous

    distance_km = haversine_distance_km(
      previous[:latitude], previous[:longitude],
      lat, lng
    )

    time_diff_hours = if @location_data[:timestamp].present?
                        # Use device provided timestamp (ms)
                        (@location_data[:timestamp].to_f / 1000 - previous[:recorded_at].to_f) / 3600
                      else
                        (Time.current - previous[:recorded_at]).to_f / 3600
                      end

    return alerts if time_diff_hours <= 0.001 # Prevent division by zero or near-instant updates

    speed_kmh = distance_km / time_diff_hours

    if speed_kmh > MAX_SPEED_KMH
      alerts << {
        type: 'impossible_travel',
        severity: :critical,
        detail: "Travel speed #{speed_kmh.round(1)} km/h exceeds #{MAX_SPEED_KMH} km/h threshold",
        distance_km: distance_km.round(2),
        time_hours: time_diff_hours.round(4),
        speed_kmh: speed_kmh.round(1)
      }
    end

    alerts
  end

  def check_mock_location_provider
    alerts = []
    provider = @location_data[:provider].to_s.downcase

    if provider == 'mock' || provider == 'test'
      alerts << {
        type: 'mock_location',
        severity: :high,
        detail: "Mock location provider detected: #{provider}"
      }
    end

    alerts
  end

  def check_gps_accuracy
    alerts = []
    accuracy = @location_data[:accuracy]&.to_f
    return alerts unless accuracy

    if accuracy < SUSPICIOUS_ACCURACY_THRESHOLD
      alerts << {
        type: 'suspicious_accuracy',
        severity: :medium,
        detail: "GPS accuracy #{accuracy}m is suspiciously precise (threshold: #{SUSPICIOUS_ACCURACY_THRESHOLD}m)"
      }
    end

    if accuracy > 500
      alerts << {
        type: 'poor_accuracy',
        severity: :low,
        detail: "GPS accuracy #{accuracy}m indicates poor signal or interference"
      }
    end

    alerts
  end

  def check_spoofing_apps
    alerts = []
    installed = @location_data[:installed_apps]
    return alerts unless installed.is_a?(Array)

    found = installed.select { |app| KNOWN_SPOOF_APPS.include?(app.to_s) }

    found.each do |app|
      alerts << {
        type: 'spoofing_app_detected',
        severity: :critical,
        detail: "Known GPS spoofing app installed: #{app}"
      }
    end

    alerts
  end

  def last_known_location
    location = GeoLocation.where(smartphone: @smartphone)
                          .order(created_at: :desc)
                          .first

    return nil unless location

    {
      latitude: location.latitude.to_f,
      longitude: location.longitude.to_f,
      recorded_at: location.created_at
    }
  rescue StandardError => e
    Rails.logger.warn("[GpsSpoofingDetector] Failed to fetch last location: #{e.message}")
    nil
  end

  def haversine_distance_km(lat1, lng1, lat2, lng2)
    d_lat = to_rad(lat2 - lat1)
    d_lng = to_rad(lng2 - lng1)

    a = Math.sin(d_lat / 2)**2 +
        Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * Math.sin(d_lng / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    EARTH_RADIUS_KM * c
  end

  def to_rad(degrees)
    degrees * Math::PI / 180.0
  end

  def calculate_risk_score(alerts)
    return 0 if alerts.empty?

    weights = { critical: 40, high: 25, medium: 15, low: 5 }
    score = alerts.sum { |a| weights[a[:severity]] || 5 }
    [score, 100].min
  end
end
