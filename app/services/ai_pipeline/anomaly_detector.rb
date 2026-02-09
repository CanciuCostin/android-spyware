# frozen_string_literal: true

module AiPipeline
  class AnomalyDetector
    SUPPORTED_TYPES = %w[location usage sms call keylog app_usage].freeze
    Z_SCORE_THRESHOLD = 2.5
    IQR_MULTIPLIER = 1.5

    def handles?(data_type)
      SUPPORTED_TYPES.include?(data_type.to_s)
    end

    def process(context)
      device = Smartphone.find_by(device_id: context[:device_id])
      return context unless device

      anomalies = []
      anomalies.concat(detect_statistical_anomalies(device, context))
      anomalies.concat(detect_location_anomalies(device, context)) if context[:data_type].to_s == 'location'
      anomalies.concat(detect_usage_anomalies(device, context))

      context[:anomalies] = anomalies
      generate_alerts(device, anomalies) if anomalies.any?

      context
    end

    # Build a baseline profile for a device over the given period
    def self.build_baseline(device, period_days: 30)
      since = period_days.days.ago
      {
        keylog_hourly: hourly_distribution(device.keylogs.where('created_at > ?', since)),
        sms_daily: daily_counts(device.sms_messages.where('created_at > ?', since)),
        call_daily: daily_counts(device.call_logs.where('created_at > ?', since)),
        location_clusters: location_clusters(device.geo_locations.where('created_at > ?', since)),
        computed_at: Time.current
      }
    end

    private

    # Z-score anomaly detection on activity counts
    def detect_statistical_anomalies(device, context)
      anomalies = []
      counts = recent_daily_counts(device, context[:data_type])
      return anomalies if counts.size < 7

      mean = counts.sum.to_f / counts.size
      return anomalies if mean.zero?

      std_dev = Math.sqrt(counts.map { |c| (c - mean)**2 }.sum / counts.size)
      return anomalies if std_dev.zero?

      current = counts.last || 0
      z_score = (current - mean) / std_dev

      if z_score.abs > Z_SCORE_THRESHOLD
        anomalies << {
          type: :statistical,
          subtype: z_score > 0 ? :spike : :drop,
          severity: z_score.abs > 4 ? :critical : :high,
          data_type: context[:data_type],
          z_score: z_score.round(2),
          current_value: current,
          mean: mean.round(2),
          message: "Unusual #{context[:data_type]} activity: z-score #{z_score.round(2)}"
        }
      end

      # IQR-based detection
      sorted = counts.sort
      q1 = sorted[sorted.size / 4] || 0
      q3 = sorted[(sorted.size * 3) / 4] || 0
      iqr = q3 - q1
      lower_bound = q1 - (IQR_MULTIPLIER * iqr)
      upper_bound = q3 + (IQR_MULTIPLIER * iqr)

      if current < lower_bound || current > upper_bound
        anomalies << {
          type: :statistical,
          subtype: :iqr_outlier,
          severity: :medium,
          data_type: context[:data_type],
          current_value: current,
          bounds: { lower: lower_bound.round(2), upper: upper_bound.round(2) },
          message: "IQR outlier for #{context[:data_type]}: #{current} outside [#{lower_bound.round(2)}, #{upper_bound.round(2)}]"
        }
      end

      anomalies
    end

    # Detect unusual locations
    def detect_location_anomalies(device, context)
      anomalies = []
      payload = context[:payload]
      return anomalies unless payload[:latitude] && payload[:longitude]

      known_locations = device.geo_locations
        .where('created_at > ?', 30.days.ago)
        .pluck(:latitude, :longitude)
      return anomalies if known_locations.size < 10

      lat = payload[:latitude].to_f
      lng = payload[:longitude].to_f

      # Check if location is far from all known clusters
      min_distance = known_locations.map { |klat, klng| haversine(lat, lng, klat.to_f, klng.to_f) }.min
      threshold_km = (ENV['ANOMALY_LOCATION_THRESHOLD_KM'].presence || 50).to_f

      if min_distance && min_distance > threshold_km
        anomalies << {
          type: :location,
          subtype: :unusual_place,
          severity: :high,
          latitude: lat,
          longitude: lng,
          distance_km: min_distance.round(2),
          message: "Device at unusual location: #{min_distance.round(1)}km from known areas"
        }
      end

      anomalies
    end

    # Detect unusual usage hours or patterns
    def detect_usage_anomalies(device, context)
      anomalies = []
      current_hour = Time.current.hour

      # Build hourly activity profile from keylogs
      hourly_counts = if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
                        device.keylogs.where('created_at > ?', 30.days.ago)
                              .group("strftime('%H', created_at)").count
                      else
                        device.keylogs.where('created_at > ?', 30.days.ago)
                              .group("EXTRACT(HOUR FROM created_at)").count
                      end

      return anomalies if hourly_counts.size < 12

      avg_at_hour = hourly_counts.values.sum.to_f / 24
      current_hour_avg = hourly_counts[current_hour.to_s] || hourly_counts[current_hour] || 0

      # Activity during normally quiet hours
      if current_hour_avg < (avg_at_hour * 0.1) && context[:payload].present?
        anomalies << {
          type: :usage,
          subtype: :unusual_hour,
          severity: :medium,
          hour: current_hour,
          typical_activity: current_hour_avg,
          message: "Activity at unusual hour (#{current_hour}:00) - typically inactive"
        }
      end

      anomalies
    end

    def generate_alerts(device, anomalies)
      anomalies.each do |anomaly|
        AlertService.trigger(
          "anomaly_#{anomaly[:type]}",
          device,
          anomaly.merge(detected_at: Time.current)
        )
      end
    rescue StandardError => e
      Rails.logger.error("[AnomalyDetector] Alert generation failed: #{e.message}")
    end

    def recent_daily_counts(device, data_type)
      relation = case data_type.to_s
                 when 'sms'     then device.sms_messages
                 when 'call'    then device.call_logs
                 when 'keylog'  then device.keylogs
                 when 'location' then device.geo_locations
                 else return []
                 end

      # Cache the result for 1 hour to avoid repeated heavy queries
      Rails.cache.fetch("ai_pipeline:counts:#{device.id}:#{data_type}", expires_in: 1.hour) do
        counts_query = relation.where('created_at > ?', 30.days.ago)
        
        if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
          counts_query.group("date(created_at)").order("date(created_at) ASC").count.values
        else
          counts_query.group("DATE(created_at)").order("DATE(created_at) ASC").count.values
        end
      end
    end

    def haversine(lat1, lng1, lat2, lng2)
      return 0.0 if lat1 == lat2 && lng1 == lng2
      
      # Use Math methods more efficiently
      dtor = Math::PI / 180
      r = 6371.0
      
      dlat = (lat2 - lat1) * dtor
      dlng = (lng2 - lng1) * dtor
      
      a = Math.sin(dlat / 2)**2 +
          Math.cos(lat1 * dtor) * Math.cos(lat2 * dtor) *
          Math.sin(dlng / 2)**2
      
      2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end

    def self.hourly_distribution(relation)
      if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
        relation.group("strftime('%H', created_at)").count
      else
        relation.group("EXTRACT(HOUR FROM created_at)").count
      end
    end

    def self.daily_counts(relation)
      if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
        relation.group("date(created_at)").count.values
      else
        relation.group("DATE(created_at)").count.values
      end
    end

    def self.location_clusters(relation)
      relation.pluck(:latitude, :longitude).compact
    end
  end
end
