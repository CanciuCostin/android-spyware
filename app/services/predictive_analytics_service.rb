# frozen_string_literal: true

class PredictiveAnalyticsService < ApplicationService
  def initialize(device, options = {})
    @device = device
    @days = options[:days] || 30
    @start_date = options[:start_date] || @days.days.ago
  end

  def call
    return Result.failure('Device is required') unless @device

    Result.success(
      location_prediction: predict_next_location,
      activity_forecast: forecast_activity,
      risk_score: calculate_risk_score,
      contact_importance: score_contact_importance
    )
  rescue StandardError => e
    Rails.logger.error("[PredictiveAnalyticsService] #{e.message}")
    Result.failure(e.message)
  end

  # --- Location Prediction ---

  def predict_next_location
    current_hour = Time.current.hour
    current_dow = Time.current.wday

    # Find locations visited at the same hour/day-of-week historically
    candidates = historical_locations_at(current_hour, current_dow)
    return { predicted: nil, confidence: 0, message: 'Insufficient location data' } if candidates.empty?

    cluster = most_frequent_cluster(candidates)
    total = candidates.size
    cluster_count = cluster[:count]

    {
      predicted: { latitude: cluster[:lat], longitude: cluster[:lng] },
      confidence: (cluster_count.to_f / total * 100).round(1),
      based_on: total,
      typical_for: "#{Date::DAYNAMES[current_dow]} at #{current_hour}:00"
    }
  rescue StandardError => e
    { predicted: nil, confidence: 0, error: e.message }
  end

  # --- Activity Forecasting ---

  def forecast_activity
    daily_stats = activity_by_day_of_week
    hourly_stats = activity_by_hour

    {
      peak_day: daily_stats.max_by { |_, v| v }&.first,
      quietest_day: daily_stats.min_by { |_, v| v }&.first,
      peak_hours: hourly_stats.sort_by { |_, v| -v }.first(3).map { |h, c| { hour: h, avg_events: c } },
      daily_averages: daily_stats.map { |day, avg| { day: day, avg_events: avg } },
      hourly_distribution: hourly_stats.map { |hour, avg| { hour: hour, avg_events: avg } },
      trend: calculate_trend
    }
  rescue StandardError => e
    { error: e.message }
  end

  # --- Risk Scoring ---

  def calculate_risk_score
    scores = {
      location_anomaly: location_anomaly_score,
      activity_anomaly: activity_anomaly_score,
      communication_anomaly: communication_anomaly_score,
      temporal_anomaly: temporal_anomaly_score
    }

    weights = { location_anomaly: 0.3, activity_anomaly: 0.25, communication_anomaly: 0.25, temporal_anomaly: 0.2 }
    composite = scores.sum { |k, v| v * weights[k] }.round(1)

    {
      composite_score: composite,
      level: risk_level(composite),
      components: scores,
      factors: risk_factors(scores),
      updated_at: Time.current.iso8601
    }
  rescue StandardError => e
    { composite_score: 0, level: 'unknown', error: e.message }
  end

  # --- Contact Importance Scoring ---

  def score_contact_importance
    contacts = {}

    @device.sms_messages.where('created_at >= ?', @start_date)
           .group(:address).count.each do |addr, count|
      contacts[addr] ||= { sms: 0, calls: 0, recency: nil }
      contacts[addr][:sms] = count
    end

    @device.call_logs.where('created_at >= ?', @start_date)
           .group(:phone_number).count.each do |num, count|
      contacts[num] ||= { sms: 0, calls: 0, recency: nil }
      contacts[num][:calls] = count
    end

    # Recency bonus
    contacts.each_key do |contact|
      last_sms = @device.sms_messages.where(address: contact).order(created_at: :desc).first
      last_call = @device.call_logs.where(phone_number: contact).order(created_at: :desc).first
      latest = [last_sms&.created_at, last_call&.created_at].compact.max
      contacts[contact][:recency] = latest&.iso8601
    end

    scored = contacts.map do |contact, data|
      frequency_score = (data[:sms] + data[:calls] * 2).clamp(0, 100)
      recency_score = data[:recency] ? recency_weight(Time.parse(data[:recency])) : 0
      importance = ((frequency_score * 0.6) + (recency_score * 0.4)).round(1)

      { contact: contact, importance: importance, sms_count: data[:sms], call_count: data[:calls], last_contact: data[:recency] }
    end

    scored.sort_by { |c| -c[:importance] }.first(20)
  rescue StandardError => e
    Rails.logger.error("[PredictiveAnalyticsService] Contact scoring error: #{e.message}")
    []
  end

  private

  # --- Location helpers ---

  def historical_locations_at(hour, dow)
    @device.geo_locations
           .where('created_at >= ?', @start_date)
           .where("EXTRACT(HOUR FROM created_at) = ?", hour)
           .where("EXTRACT(DOW FROM created_at) = ?", dow)
           .pluck(:latitude, :longitude)
           .map { |lat, lng| { lat: lat.to_f, lng: lng.to_f } }
  rescue StandardError
    # Fallback for SQLite or other DBs
    @device.geo_locations
           .where('created_at >= ?', @start_date)
           .select { |l| l.created_at.hour == hour && l.created_at.wday == dow }
           .map { |l| { lat: l.latitude.to_f, lng: l.longitude.to_f } }
  end

  def most_frequent_cluster(points, radius_km: 0.5)
    return { lat: 0, lng: 0, count: 0 } if points.empty?

    best = { lat: 0, lng: 0, count: 0 }
    points.each do |center|
      nearby = points.count do |p|
        haversine_km(center[:lat], center[:lng], p[:lat], p[:lng]) <= radius_km
      end
      best = { lat: center[:lat], lng: center[:lng], count: nearby } if nearby > best[:count]
    end
    best
  end

  def haversine_km(lat1, lng1, lat2, lng2)
    r = 6371.0
    d_lat = (lat2 - lat1) * Math::PI / 180
    d_lng = (lng2 - lng1) * Math::PI / 180
    a = Math.sin(d_lat / 2)**2 + Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(d_lng / 2)**2
    r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  # --- Activity helpers ---

  def activity_by_day_of_week
    counts = Hash.new { |h, k| h[k] = [] }
    weeks = (@days / 7.0).ceil

    @device.keylogs.where('created_at >= ?', @start_date).find_each do |k|
      counts[Date::DAYNAMES[k.created_at.wday]] << 1
    end

    counts.transform_values { |v| (v.size.to_f / [weeks, 1].max).round(1) }
  rescue StandardError
    {}
  end

  def activity_by_hour
    counts = Hash.new(0)
    days_count = [(@days), 1].max

    @device.keylogs.where('created_at >= ?', @start_date).find_each do |k|
      counts[k.created_at.hour] += 1
    end

    counts.transform_values { |v| (v.to_f / days_count).round(1) }
  rescue StandardError
    {}
  end

  def calculate_trend
    midpoint = @start_date + (@days / 2).days
    first_half = @device.keylogs.where(created_at: @start_date..midpoint).count
    second_half = @device.keylogs.where(created_at: midpoint..Time.current).count

    if first_half == 0 && second_half == 0
      'stable'
    elsif second_half > first_half * 1.2
      'increasing'
    elsif second_half < first_half * 0.8
      'decreasing'
    else
      'stable'
    end
  rescue StandardError
    'unknown'
  end

  # --- Risk scoring helpers ---

  def location_anomaly_score
    recent_locations = @device.geo_locations.where('created_at >= ?', 24.hours.ago).pluck(:latitude, :longitude)
    return 0 if recent_locations.size < 2

    historical = @device.geo_locations.where('created_at >= ?', @start_date).where('created_at < ?', 24.hours.ago)
                        .pluck(:latitude, :longitude)
    return 0 if historical.empty?

    hist_center = { lat: historical.map(&:first).sum / historical.size.to_f,
                    lng: historical.map(&:last).sum / historical.size.to_f }

    anomalous = recent_locations.count do |lat, lng|
      haversine_km(lat.to_f, lng.to_f, hist_center[:lat], hist_center[:lng]) > 50
    end

    (anomalous.to_f / recent_locations.size * 100).clamp(0, 100).round(1)
  rescue StandardError
    0
  end

  def activity_anomaly_score
    recent_count = @device.keylogs.where('created_at >= ?', 24.hours.ago).count
    avg_daily = @device.keylogs.where('created_at >= ?', @start_date).count.to_f / [(@days), 1].max

    return 0 if avg_daily == 0

    deviation = ((recent_count - avg_daily).abs / avg_daily * 50).clamp(0, 100).round(1)
    deviation
  rescue StandardError
    0
  end

  def communication_anomaly_score
    recent_contacts = @device.sms_messages.where('created_at >= ?', 24.hours.ago).distinct.count(:address)
    avg_contacts = @device.sms_messages.where('created_at >= ?', @start_date)
                          .group("DATE(created_at)").select("COUNT(DISTINCT address)").length rescue 0

    avg_daily = avg_contacts.to_f / [(@days), 1].max
    return 0 if avg_daily == 0

    ((recent_contacts - avg_daily).abs / avg_daily * 50).clamp(0, 100).round(1)
  rescue StandardError
    0
  end

  def temporal_anomaly_score
    night_activity = @device.keylogs.where('created_at >= ?', 7.days.ago)
                           .select { |k| k.created_at.hour.between?(0, 5) }.size
    total_activity = @device.keylogs.where('created_at >= ?', 7.days.ago).count

    return 0 if total_activity == 0

    night_ratio = night_activity.to_f / total_activity
    (night_ratio * 200).clamp(0, 100).round(1)
  rescue StandardError
    0
  end

  def risk_level(score)
    case score
    when 0..20   then 'low'
    when 21..50  then 'medium'
    when 51..75  then 'high'
    else              'critical'
    end
  end

  def risk_factors(scores)
    factors = []
    factors << 'Unusual location patterns detected' if scores[:location_anomaly] > 40
    factors << 'Abnormal activity volume' if scores[:activity_anomaly] > 40
    factors << 'Unusual communication patterns' if scores[:communication_anomaly] > 40
    factors << 'Significant late-night activity' if scores[:temporal_anomaly] > 40
    factors << 'No significant anomalies detected' if factors.empty?
    factors
  end

  def recency_weight(time)
    days_ago = (Time.current - time) / 1.day
    case days_ago
    when 0..1   then 100
    when 1..7   then 75
    when 7..14  then 50
    when 14..30 then 25
    else 10
    end
  end
end
