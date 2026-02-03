module CommandSender
  extend ActiveSupport::Concern
  
  def send_command_async(smartphone, command, params = {})
    request_id = SecureRandom.uuid
    device_id = smartphone.device_id
    
    raise "Device ID not set for smartphone #{smartphone.id}" unless device_id
    
    # Create pending command record
    pending_command = PendingCommand.create!(
      smartphone: smartphone,
      request_id: request_id,
      command: command,
      params: params,
      status: :pending
    )
    
    # Broadcast command to device via ActionCable
    ActionCable.server.broadcast(
      "command_channel_#{device_id}",
      {
        request_id: request_id,
        command: command,
        params: params
      }
    )
    
    Rails.logger.info("Sent command #{command} to device #{device_id}, request_id: #{request_id}")
    
    pending_command
  end
  
  def wait_for_response(pending_command, timeout: 30.seconds)
    start_time = Time.current
    
    loop do
      pending_command.reload
      
      if pending_command.completed? || pending_command.failed? || pending_command.timeout?
        return pending_command
      end
      
      if Time.current - start_time > timeout
        pending_command.mark_failed("Timeout waiting for response")
        return pending_command
      end
      
      sleep 0.5
    end
  end
  
  def send_command_and_wait(smartphone, command, params = {}, timeout: 30.seconds)
    pending_command = send_command_async(smartphone, command, params)
    wait_for_response(pending_command, timeout: timeout)
  end
end
