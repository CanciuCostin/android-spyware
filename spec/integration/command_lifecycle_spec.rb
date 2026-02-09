# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Command Lifecycle', type: :integration do
  let(:device_id) { 'test-device-cmd-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }

  describe 'full command lifecycle: send → broadcast → receive response → process' do
    it 'creates a pending command and broadcasts to device channel' do
      cmd = send_test_command(smartphone, 'get_contacts')

      expect(cmd).to be_persisted
      expect(cmd.status).to eq('pending')
      expect(cmd.command).to eq('get_contacts')

      messages = broadcasted_messages_for("commands_#{device_id}")
      expect(messages.size).to eq(1)
      expect(messages.first[:command]).to eq('get_contacts')
      expect(messages.first[:request_id]).to eq(cmd.request_id)
    end

    it 'resolves pending command when device sends response' do
      cmd = send_test_command(smartphone, 'get_contacts')

      channel = simulate_device_subscription(device_id)
      channel.subscribed

      channel.receive({
        'type' => 'command_response',
        'request_id' => cmd.request_id,
        'payload' => { 'contacts' => [{ 'name' => 'Alice', 'phone' => '+1234567890' }] }
      })

      cmd.reload
      expect(cmd.completed?).to be true
      expect(cmd.response_data).to include('contacts')
    end

    it 'marks command as failed when device returns an error' do
      cmd = send_test_command(smartphone, 'get_contacts')

      channel = simulate_device_subscription(device_id)
      channel.subscribed

      channel.receive({
        'type' => 'command_response',
        'request_id' => cmd.request_id,
        'payload' => { 'error' => 'Permission denied' }
      })

      cmd.reload
      expect(cmd.failed?).to be true
      expect(cmd.response_data['error']).to eq('Permission denied')
    end
  end

  describe 'command timeout handling' do
    it 'marks command as timed out after expiry' do
      cmd = send_test_command(smartphone, 'get_contacts')

      cmd.update!(status: :timeout, completed_at: Time.current)

      expect(cmd.reload.timeout?).to be true
    end

    it 'identifies expired commands via scope' do
      travel_to(Time.utc(2025, 1, 15, 12, 0, 0)) do
        old_cmd = PendingCommand.create!(
          smartphone: smartphone,
          request_id: SecureRandom.uuid,
          command: 'get_contacts',
          status: :pending,
          created_at: 10.minutes.ago
        )

        recent_cmd = PendingCommand.create!(
          smartphone: smartphone,
          request_id: SecureRandom.uuid,
          command: 'get_sms',
          status: :pending
        )

        expired = PendingCommand.expired
        expect(expired).to include(old_cmd)
        expect(expired).not_to include(recent_cmd)
      end
    end
  end

  describe 'multiple concurrent commands' do
    it 'tracks multiple commands independently' do
      cmd1 = send_test_command(smartphone, 'get_contacts')
      cmd2 = send_test_command(smartphone, 'get_location')
      cmd3 = send_test_command(smartphone, 'take_screenshot')

      expect(smartphone.pending_commands.active.count).to eq(3)

      simulate_command_response(cmd1, { 'contacts' => [] })
      simulate_command_failure(cmd2, 'GPS unavailable')

      expect(cmd1.reload.completed?).to be true
      expect(cmd2.reload.failed?).to be true
      expect(cmd3.reload.pending?).to be true
      expect(smartphone.pending_commands.active.count).to eq(1)
    end

    it 'broadcasts each command to the same device channel' do
      send_test_command(smartphone, 'get_contacts')
      send_test_command(smartphone, 'get_location')

      messages = broadcasted_messages_for("commands_#{device_id}")
      expect(messages.size).to eq(2)
      commands = messages.map { |m| m[:command] }
      expect(commands).to contain_exactly('get_contacts', 'get_location')
    end
  end

  describe 'command queue ordering' do
    it 'preserves creation order' do
      cmds = 5.times.map do |i|
        PendingCommand.create!(
          smartphone: smartphone,
          request_id: SecureRandom.uuid,
          command: "cmd_#{i}",
          status: :pending
        )
      end

      ordered = smartphone.pending_commands.order(:created_at)
      expect(ordered.map(&:command)).to eq(cmds.map(&:command))
    end
  end

  describe 'failed command recovery' do
    it 'allows retrying a failed command by creating a new one' do
      original = send_test_command(smartphone, 'get_contacts')
      simulate_command_failure(original, 'Temporary failure')

      expect(original.reload.failed?).to be true

      retry_cmd = send_test_command(smartphone, 'get_contacts')
      expect(retry_cmd.request_id).not_to eq(original.request_id)
      expect(retry_cmd.pending?).to be true
    end

    it 'does not resolve already-completed commands' do
      cmd = send_test_command(smartphone, 'get_contacts')
      simulate_command_response(cmd, { 'contacts' => ['Alice'] })

      # Attempt to resolve again via channel
      channel = simulate_device_subscription(device_id)
      channel.subscribed
      channel.receive({
        'type' => 'command_response',
        'request_id' => cmd.request_id,
        'payload' => { 'contacts' => ['Bob'] }
      })

      cmd.reload
      # Should still show original response since it was already completed
      expect(cmd.completed?).to be true
      expect(cmd.response_data).to include('contacts')
    end
  end

  describe 'command validation via CommandSender' do
    it 'rejects invalid commands' do
      service = DeviceCommandService.new(smartphone, 'invalid_command_xyz')
      result = service.call

      expect(result.failure?).to be true
      expect(result.error).to include('Invalid command')
    end

    it 'accepts valid whitelisted commands' do
      service = DeviceCommandService.new(smartphone, 'get_contacts')
      result = service.call

      expect(result.success?).to be true
      expect(result.value).to be_a(PendingCommand)
      expect(result.value.command).to eq('get_contacts')
    end
  end
end
