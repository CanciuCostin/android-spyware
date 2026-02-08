class GeofenceResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    geofence_data = @response['geofence'] || @response
    event_type = geofence_data['transition']&.downcase
    latitude = geofence_data['latitude']
    longitude = geofence_data['longitude']
    zones = geofence_data['zones']

    if latitude.nil? || longitude.nil?
      @pending_command.mark_failed('Invalid geofence data: missing coordinates')
      return
    end

    # Process against active geofences
    result = GeofenceService.call(
      @smartphone,
      latitude: latitude,
      longitude: longitude
    )

    if result.success?
      @pending_command.mark_completed(@response.merge(
        'events_triggered' => result.value.map { |e| { id: e.id, type: e.event_type, geofence: e.geofence.name } }
      ))
    else
      @pending_command.mark_failed("Geofence processing failed: #{result.error}")
    end
  rescue StandardError => e
    @pending_command.mark_failed("Failed to process geofence data: #{e.message}")
  end
end
