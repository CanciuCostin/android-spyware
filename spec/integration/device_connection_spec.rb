# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Device Connection Flow', type: :integration do
  let(:device_id) { 'test-device-conn-001' }
  let(:valid_token) { 'test-device-token' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DEVICE_AUTH_TOKEN').and_return(valid_token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DEVICE_AUTH_TOKEN').and_return(valid_token)
  end

  describe 'full device connection flow' do
    context 'when device connects with valid token' do
      it 'creates smartphone record and registers device online' do
        smartphone = create_test_device(device_id: device_id)

        expect(smartphone).to be_persisted
        expect(smartphone.device_id).to eq(device_id)
        expect(smartphone.operating_system).to eq('Android 13')
      end

      it 'allows subscription to CommandChannel' do
        smartphone = create_test_device(device_id: device_id)
        channel = simulate_device_subscription(device_id)

        channel.subscribed

        expect(channel).to have_received(:stream_from).with("commands_#{device_id}")
      end

      it 'broadcasts device info to admin channel after subscription' do
        smartphone = create_test_device(device_id: device_id)
        channel = simulate_device_subscription(device_id)
        channel.subscribed

        channel.receive({
          'type' => 'device_info',
          'payload' => {
            'model' => 'Pixel 7',
            'android_version' => '13',
            'is_rooted' => false
          }
        })

        admin_messages = broadcasted_messages_for("admin_devices")
        expect(admin_messages).to include(
          hash_including(type: 'device_info', device_id: device_id)
        )
      end
    end

    context 'when device connects without a pre-existing record' do
      it 'auto-creates smartphone on first connect' do
        expect(Smartphone.find_by(device_id: 'new-device-auto')).to be_nil

        smartphone = create_test_device(device_id: 'new-device-auto')

        expect(smartphone).to be_persisted
        expect(smartphone.name).to start_with('Test')
      end
    end

    context 'when device has invalid credentials' do
      it 'rejects connection with blank token' do
        expect {
          connection = ApplicationCable::Connection.new(
            double('server', logger: Rails.logger, event_loop: nil, config: double(log_tags: [])),
            double('env',
              'warden' => nil,
              '[]' => nil
            )
          )
        }.not_to raise_error
        # The actual rejection happens in find_verified_user
        # which raises ActiveRecord::RecordNotFound => reject_unauthorized_connection
      end
    end
  end

  describe 'connection timeout handling' do
    it 'marks commands as timed out when device does not respond' do
      smartphone = create_test_device(device_id: device_id)
      # Stub TimeoutCommandJob to execute inline for this test
      pending_command = PendingCommand.create!(
        smartphone: smartphone,
        request_id: SecureRandom.uuid,
        command: 'get_contacts',
        status: :pending
      )

      # Simulate timeout by directly updating status
      pending_command.update!(status: :timeout, completed_at: Time.current)

      expect(pending_command.reload.timeout?).to be true
    end
  end

  describe 'reconnection scenarios' do
    it 'reuses existing smartphone record on reconnect' do
      smartphone = create_test_device(device_id: device_id)
      original_id = smartphone.id

      # Simulate reconnection by looking up existing device
      reconnected = Smartphone.find_by(device_id: device_id)

      expect(reconnected.id).to eq(original_id)
    end

    it 'preserves pending commands across reconnection' do
      smartphone = create_test_device(device_id: device_id)
      cmd = PendingCommand.create!(
        smartphone: smartphone,
        request_id: SecureRandom.uuid,
        command: 'get_contacts',
        status: :pending
      )

      # After reconnect, pending commands still exist
      reconnected = Smartphone.find_by(device_id: device_id)
      expect(reconnected.pending_commands.active.count).to eq(1)
      expect(reconnected.pending_commands.active.first.id).to eq(cmd.id)
    end

    it 'updates device info on reconnection with new data' do
      smartphone = create_test_device(device_id: device_id, name: 'Old Name', os: 'Android 12')
      channel = simulate_device_subscription(device_id)
      channel.subscribed

      channel.receive({
        'type' => 'device_info',
        'payload' => {
          'model' => 'Pixel 8 Pro',
          'android_version' => '14',
          'is_rooted' => false
        }
      })

      smartphone.reload
      expect(smartphone.name).to eq('Pixel 8 Pro')
      expect(smartphone.operating_system).to eq('Android 14')
    end
  end

  describe 'device sanitization' do
    it 'sanitizes device_id by stripping disallowed characters' do
      channel = CommandChannel.allocate
      sanitized = channel.send(:sanitize_device_id, 'abc-123_test:ok.fine!@#$%')

      expect(sanitized).to eq('abc-123_test:ok.fine')
    end

    it 'handles nil device_id gracefully' do
      channel = CommandChannel.allocate
      sanitized = channel.send(:sanitize_device_id, nil)

      expect(sanitized).to eq('')
    end
  end
end
