class DeviceinfoResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    device_info = @response
    @smartphone.update(
      operating_system: "Android #{device_info['android_version']}",
      name: device_info['device_model'] || @smartphone.name,
      is_rooted: device_info['is_rooted'] || false
    )
    @pending_command.mark_completed(@response)
  end
end
