require 'rails_helper'

RSpec.describe HeartbeatMonitor do
  let(:redis) { instance_double('Redis') }
  let(:device_id) { 'device-xyz' }
  let(:timestamp) { Time.at(1_600_000_000) }

  before do
    allow(RedisPool).to receive(:with).and_yield(redis)
  end

  describe '.process_heartbeat' do
    before do
      allow(Time).to receive(:current).and_return(timestamp)
    end

    it 'stores heartbeat metadata and marks device online' do
      metadata = { battery: 90 }

      expect(redis).to receive(:set).with("last_seen_#{device_id}", timestamp.to_i, ex: HeartbeatMonitor::HEARTBEAT_TTL * 2)
      expect(redis).to receive(:sadd).with('online_devices', device_id)
      expect(redis).to receive(:set).with("device_metadata_#{device_id}", metadata.to_json, ex: HeartbeatMonitor::HEARTBEAT_TTL * 2)

      expect(described_class.process_heartbeat(device_id, metadata)).to be true
    end

    it 'stores heartbeat without metadata when none provided' do
      expect(redis).to receive(:set).with("last_seen_#{device_id}", timestamp.to_i, ex: HeartbeatMonitor::HEARTBEAT_TTL * 2)
      expect(redis).to receive(:sadd).with('online_devices', device_id)
      expect(redis).not_to receive(:set).with("device_metadata_#{device_id}", any_args)

      described_class.process_heartbeat(device_id)
    end
  end

  describe '.get_last_seen' do
    it 'returns parsed time when value present' do
      allow(redis).to receive(:get).with("last_seen_#{device_id}").and_return('1600000000')

      expect(described_class.get_last_seen(device_id)).to eq(Time.at(1_600_000_000))
    end

    it 'returns nil when timestamp missing' do
      allow(redis).to receive(:get).and_return(nil)

      expect(described_class.get_last_seen(device_id)).to be_nil
    end
  end

  describe '.is_online?' do
    it 'delegates membership check to redis' do
      expect(redis).to receive(:sismember).with('online_devices', device_id).and_return(true)

      expect(described_class.is_online?(device_id)).to be true
    end
  end

  describe '.get_all_online_devices' do
    it 'returns device list from redis' do
      expect(redis).to receive(:smembers).with('online_devices').and_return(%w[device-1 device-2])

      expect(described_class.get_all_online_devices).to match_array(%w[device-1 device-2])
    end
  end

  describe '.mark_offline' do
    it 'cleans redis keys for the device' do
      expect(redis).to receive(:srem).with('online_devices', device_id)
      expect(redis).to receive(:del).with("last_seen_#{device_id}")
      expect(redis).to receive(:del).with("device_metadata_#{device_id}")

      expect(described_class.mark_offline(device_id)).to be true
    end
  end

  describe '.cleanup_stale_heartbeats' do
    before do
      allow(redis).to receive(:smembers).with('online_devices').and_return([device_id])
      allow(RedisPool).to receive(:with).and_yield(redis)
      allow(Time).to receive(:current).and_return(timestamp + HeartbeatMonitor::HEARTBEAT_TTL + 1)
      allow(redis).to receive(:get).with("last_seen_#{device_id}").and_return(timestamp.to_i.to_s)
      allow(described_class).to receive(:mark_offline).and_return(true)
    end

    it 'marks stale devices offline and returns count' do
      expect(described_class.cleanup_stale_heartbeats).to eq(1)
      expect(described_class).to have_received(:mark_offline).with(device_id)
    end
  end
end
