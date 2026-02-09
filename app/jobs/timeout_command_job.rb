class TimeoutCommandJob < ApplicationJob
  queue_as :default
  
  def perform(pending_command_id)
    command = PendingCommand.find_by(id: pending_command_id)
    return unless command
    return unless command.pending? || command.processing?
    
    command.update!(
      status: :timeout,
      response_data: { error: "Command timeout after 5 minutes" },
      completed_at: Time.current
    )
    
    ActionCable.server.broadcast(
      "command_status_#{command.smartphone.device_id}",
      {
        request_id: command.request_id,
        status: "timeout",
        error: "Command timeout"
      }
    )
  end
end
