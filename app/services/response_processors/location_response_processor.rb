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
    accuracy = location_data['accuracy']
    
    if latitude && longitude
      GeoLocation.create!(
        smartphone: @smartphone,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        captured_at: Time.now
      )
      @pending_command.mark_completed(@response)
    else
      @pending_command.mark_failed('Invalid location data')
    end
  end
end
