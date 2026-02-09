class DeviceInfoResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    device_info = @response || {}
    updates = {}

    version = device_info['android_version']
    updates[:operating_system] = "Android #{version}" if version.present?

    model = device_info['device_model'].presence || device_info['model'].presence
    updates[:name] = model if model.present?

    unless device_info['is_rooted'].nil?
      updates[:is_rooted] = ActiveModel::Type::Boolean.new.cast(device_info['is_rooted'])
    end

    @smartphone.update(updates) if updates.any?
    @pending_command.mark_completed(@response)
  end
end
