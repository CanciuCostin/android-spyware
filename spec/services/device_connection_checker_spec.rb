require 'rails_helper'

RSpec.describe DeviceConnectionChecker do
  let(:redis) { instance_double('Redis') }
  let(:smartphone) { create(:smartphone) }

  before do
    allow(RedisPool).to receive(:with).and_yield(redis)
  end

  describe '.check_device_online' do
    it 'delegates to redis membership check' do
      expect(redis).to receive(:sismember).with('online_devices', smartphone.device_id).and_return(true)

      expect(described_class.check_device_online(smartphone)).to be true
    end
  end

  describe '.get_online_devices' do
    it 'returns all online device ids' do
      expect(redis).to receive(:smembers).with('online_devices').and_return(%w[a b])

      expect(described_class.get_online_devices).to match_array(%w[a b])
    end
  end

  describe '.get_device_info' do
    it 'parses stored metadata when present' do
      payload = { 'status' => 'ok' }.to_json
      expect(redis).to receive(:get).with("device_info:#{smartphone.device_id}").and_return(payload)

      expect(described_class.get_device_info(smartphone.device_id)).to eq(JSON.parse(payload))
    end

    it 'returns nil when no info exists' do
      expect(redis).to receive(:get).and_return(nil)

      expect(described_class.get_device_info(smartphone.device_id)).to be_nil
    end
  end
end
