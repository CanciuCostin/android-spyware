# frozen_string_literal: true

# Helpers for sending and tracking commands in integration tests.
module CommandHelpers
  def send_test_command(smartphone, command, params = {})
    request_id = SecureRandom.uuid

    pending_command = PendingCommand.create!(
      smartphone: smartphone,
      request_id: request_id,
      command: command,
      params: params,
      status: :pending
    )

    ActionCable.server.broadcast(
      "commands_#{smartphone.device_id}",
      {
        request_id: request_id,
        command: command,
        params: params
      }
    )

    pending_command
  end

  def simulate_command_response(pending_command, response_data = {})
    pending_command.mark_completed(response_data)
    pending_command
  end

  def simulate_command_failure(pending_command, error_message = 'Device error')
    pending_command.mark_failed(error_message)
    pending_command
  end

  def create_completed_command(smartphone, command: 'get_contacts', response: { 'contacts' => [] })
    cmd = PendingCommand.create!(
      smartphone: smartphone,
      request_id: SecureRandom.uuid,
      command: command,
      status: :pending
    )
    cmd.mark_completed(response)
    cmd
  end

  def create_failed_command(smartphone, command: 'get_contacts', error: 'timeout')
    cmd = PendingCommand.create!(
      smartphone: smartphone,
      request_id: SecureRandom.uuid,
      command: command,
      status: :pending
    )
    cmd.mark_failed(error)
    cmd
  end

  # Stub TimeoutCommandJob to avoid needing ActiveJob backend
  def stub_timeout_job
    if defined?(TimeoutCommandJob)
      allow(TimeoutCommandJob).to receive_message_chain(:set, :perform_later)
    end
  end
end

RSpec.configure do |config|
  config.include CommandHelpers, type: :integration
end
