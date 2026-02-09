class LocationResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    location_data = @response['location'] || {}
    latitude = location_data['latitude']
    longitude = location_data['longitude']

    # Validate required location data
    if latitude.nil? || longitude.nil?
      @pending_command.mark_failed('Invalid location data: missing latitude or longitude')
      return
    end

    begin
      # Extract additional location data (provider, accuracy, etc.)
      provider = location_data['provider']
      accuracy = location_data['accuracy']
      speed = location_data['speed']
      bearing = location_data['bearing']
      altitude = location_data['altitude']
      timestamp = location_data['timestamp']

      # Deduplicate by coordinates (numeric comparison with tolerance) within a short time window
      existing = GeoLocation.where(smartphone: @smartphone)
                            .where('ABS(latitude - ?) < 0.0001 AND ABS(longitude - ?) < 0.0001', latitude, longitude)
                            .where('created_at > ?', 1.minute.ago)
                            .exists?

      unless existing
        GeoLocation.create!(
          smartphone: @smartphone,
          latitude: latitude,
          longitude: longitude
        )
      end

      # Optional: Save location data to file for legacy behavior/backup
      save_location_to_file(location_data, provider, accuracy) if ENV['SAVE_LOCATION_FILES'] == 'true'

      # Mark command as completed with response data
      @pending_command.mark_completed(@response)
    rescue StandardError => e
      @pending_command.mark_failed("Failed to process location: #{e.message}")
    end
  end

  private

  # Optional method for legacy file-saving behavior
  def save_location_to_file(location_data, provider, accuracy)
    timestamp = Time.current.strftime("%Y-%m-%d_%H--%M--%S")
    filename = "location_#{timestamp}.txt"
    file_path = Rails.root.join('files', 'dumps', 'locations', filename)

    FileUtils.mkdir_p(File.dirname(file_path))

    content = format_location_content(location_data, provider, accuracy)
    File.write(file_path, content)

    # Store file path in response for audit trail
    @response['file_path'] = file_path.to_s
  rescue StandardError => e
    Rails.logger.warn("Failed to save location to file: #{e.message}")
  end

  def format_location_content(location_data, provider, accuracy)
    latitude = location_data['latitude']
    longitude = location_data['longitude']
    speed = location_data['speed']
    bearing = location_data['bearing']
    altitude = location_data['altitude']

    <<~CONTENT
      Location Data
      ==============
      Latitude: #{latitude}
      Longitude: #{longitude}
      Provider: #{provider}
      Accuracy: #{accuracy}m
      Speed: #{speed} m/s
      Bearing: #{bearing}°
      Altitude: #{altitude}m
    CONTENT
  end
end
