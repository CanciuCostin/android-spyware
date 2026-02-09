require 'rails_helper'

RSpec.describe CommandChannel, type: :channel do
  let(:redis) { instance_double('Redis', sadd: true, set: true, srem: true) }
  let(:smartphone) { create(:smartphone, device_id: 'channel-device') }
  let!(:pending_command) { create(:pending_command, smartphone: smartphone, request_id: 'req-456') }

  before do
    stub_connection current_user_type: :admin
    allow_any_instance_of(PendingCommand).to receive(:schedule_timeout)
    allow(RedisPool).to receive(:with).and_yield(redis)
    allow(ActionCable.server).to receive(:broadcast)
  end

  context 'subscription lifecycle' do
    it 'confirms subscription and streams from command channel' do
      subscribe(device_id: smartphone.device_id)

      expect(subscription).to be_confirmed
      expect(streams).to include("commands_#{smartphone.device_id}")
    end
  end

  describe '#receive' do
    before do
      subscribe(device_id: smartphone.device_id)
    end

    it 'resolves pending commands when a response arrives' do
      perform(:receive, 'type' => 'response', 'request_id' => pending_command.request_id, 'payload' => { 'data' => 'ok' })

      expect(pending_command.reload.completed?).to be true
      expect(pending_command.response_data['response_type']).to eq('response')
    end
  end

  describe '#location_update' do
    before do
      subscribe(device_id: smartphone.device_id)
    end

    it 'persists location data and broadcasts to admin channel' do
      location = { 'latitude' => '10.5', 'longitude' => '20.5', 'timestamp' => '1700000000000' }
      expect(ActionCable.server).to receive(:broadcast).with("location_#{smartphone.device_id}_admin", hash_including('type' => 'location_update'))

      perform(:location_update, 'data' => location)

      expect(GeoLocation.last.smartphone).to eq(smartphone)
    end
  end

  describe '#send_command' do
    before do
      subscribe(device_id: smartphone.device_id)
    end

    it 'broadcasts admin commands to the device queue' do
      expect(ActionCable.server).to receive(:broadcast).with("commands_#{smartphone.device_id}", hash_including('action' => 'reboot'))

      perform(:send_command, 'command' => 'reboot')
    end
  end

  describe '#process_social_media_chats' do
    before do
      subscribe(device_id: smartphone.device_id)
    end

    let(:payload) do
      {
        'type' => 'social_media_chats',
        'action' => 'social_media_chats',
        'data' => [
          { 'app' => 'WhatsApp', 'sender' => 'Mom', 'content' => 'Hello', 'timestamp' => 123456789, 'message_id' => 'msg1' }
        ]
      }
    end

    it 'creates SocialMediaMessage records and handles deduplication' do
      # First run - should create
      perform(:receive, payload)
      expect(SocialMediaMessage.count).to eq(1)
      
      message = SocialMediaMessage.last
      expect(message.smartphone).to eq(smartphone)
      expect(message.app_name).to eq('WhatsApp')
      expect(message.sender).to eq('Mom')
      expect(message.body).to eq('Hello')
      expect(message.sent_at).to eq(Time.at(123456789 / 1000))

      # Second run with same data - should not create duplicate
      perform(:receive, payload)
      expect(SocialMediaMessage.count).to eq(1)
    end
  end
end
