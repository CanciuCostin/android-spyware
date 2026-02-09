# frozen_string_literal: true

module AiPipeline
  class DataEnricher
    SUPPORTED_TYPES = %w[location sms call contact app_usage keylog].freeze

    APP_CATEGORIES = {
      'com.whatsapp' => 'messaging',
      'com.facebook.orca' => 'messaging',
      'org.telegram.messenger' => 'messaging',
      'com.instagram.android' => 'social',
      'com.twitter.android' => 'social',
      'com.facebook.katana' => 'social',
      'com.google.android.gm' => 'email',
      'com.microsoft.office.outlook' => 'email',
      'com.android.chrome' => 'browser',
      'org.mozilla.firefox' => 'browser',
      'com.google.android.apps.maps' => 'navigation',
      'com.spotify.music' => 'entertainment',
      'com.google.android.youtube' => 'entertainment',
      'com.netflix.mediaclient' => 'entertainment',
      'com.android.vending' => 'system',
      'com.android.settings' => 'system',
      'com.android.phone' => 'system'
    }.freeze

    def handles?(data_type)
      SUPPORTED_TYPES.include?(data_type.to_s)
    end

    def process(context)
      context[:enrichments] ||= {}
      context[:metadata] ||= {}

      enrich_location(context) if context[:data_type].to_s == 'location'
      enrich_phone_number(context) if %w[sms call].include?(context[:data_type].to_s)
      enrich_app(context) if %w[app_usage keylog].include?(context[:data_type].to_s)
      tag_metadata(context)

      context
    end

    private

    # Reverse-geocode coordinates to an address via external API
    def enrich_location(context)
      payload = context[:payload]
      return unless payload[:latitude] && payload[:longitude]

      lat = payload[:latitude].to_f
      lng = payload[:longitude].to_f

      address = reverse_geocode(lat, lng)
      context[:enrichments][:address] = address if address
      context[:enrichments][:coordinates] = { lat: lat, lng: lng }
    rescue StandardError => e
      Rails.logger.warn("[DataEnricher] Geocoding failed: #{e.message}")
    end

    # Resolve a phone number to a known contact
    def enrich_phone_number(context)
      payload = context[:payload]
      phone = payload[:phone_number] || payload[:number] || payload[:address]
      return unless phone.present?

      device = Smartphone.find_by(device_id: context[:device_id])
      return unless device

      contact = device.contacts.find_by(phone_number: normalize_phone(phone))
      if contact
        context[:enrichments][:contact] = {
          name: contact.name,
          phone: contact.phone_number
        }
      end
    end

    # Categorize app by package name
    def enrich_app(context)
      payload = context[:payload]
      package = payload[:app_package] || payload[:package_name]
      return unless package.present?

      category = APP_CATEGORIES[package] || categorize_by_prefix(package)
      context[:enrichments][:app_category] = category
      context[:enrichments][:app_package] = package
    end

    # Attach metadata tags to the context
    def tag_metadata(context)
      context[:metadata][:processed_at] = Time.current
      context[:metadata][:device_id] = context[:device_id]
      context[:metadata][:data_type] = context[:data_type]
      context[:metadata][:hour_of_day] = Time.current.hour
      context[:metadata][:day_of_week] = Time.current.strftime('%A')
      context[:metadata][:enriched] = context[:enrichments].present?
    end

    def reverse_geocode(lat, lng)
      api_key = ENV['GEOCODING_API_KEY']
      return nil unless api_key.present?

      uri = URI("https://maps.googleapis.com/maps/api/geocode/json?latlng=#{lat},#{lng}&key=#{api_key}")
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data.dig('results', 0, 'formatted_address')
    rescue StandardError => e
      Rails.logger.warn("[DataEnricher] Geocode API error: #{e.message}")
      nil
    end

    def normalize_phone(phone)
      phone.to_s.gsub(/[^\d+]/, '')
    end

    def categorize_by_prefix(package)
      case package
      when /^com\.google\./ then 'google'
      when /^com\.samsung\./ then 'samsung'
      when /^com\.android\./ then 'system'
      when /\.(game|play)/i then 'gaming'
      when /\.(bank|pay|finance)/i then 'finance'
      when /\.(camera|photo|gallery)/i then 'media'
      else 'other'
      end
    end
  end
end
