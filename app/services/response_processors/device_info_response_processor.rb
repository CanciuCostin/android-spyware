class DeviceInfoResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    # Extract device info from response
    # Response format from Android client:
    # {
    #   "device_model": "...",
    #   "android_version": "...",
    #   "battery_level": ...,
    #   "is_rooted": true/false,
    #   ... other fields
    # }

    device_model = @response['device_model'] || @response['model']
    android_version = @response['android_version']
    battery_level = @response['battery_level']
    is_rooted = @response['is_rooted']

    # Update Smartphone record with device information
    update_data = {}
    update_data[:name] = device_model if device_model.present?
    update_data[:operating_system] = "Android #{android_version}" if android_version.present?
    update_data[:is_rooted] = is_rooted unless is_rooted.nil?

    @smartphone.update(update_data) if update_data.any?

    # Mark pending command as completed
    @pending_command.mark_completed(@response)
  end
end
