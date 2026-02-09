# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Memory Leak Detection', type: :performance do
  # Threshold for acceptable memory growth per cycle (bytes)
  ACCEPTABLE_GROWTH_PER_CYCLE = 512 * 1024 # 512KB

  before(:all) do
    @device = create(:smartphone, device_id: 'memleak-test-device')
  end

  after(:all) do
    Smartphone.where(device_id: 'memleak-test-device').destroy_all
  end

  describe 'Long-running connection simulation' do
    it 'does not grow memory during sustained heartbeat cycles' do
      GC.start
      GC.compact if GC.respond_to?(:compact)
      initial_memory = current_memory_rss

      samples = []
      50.times do |cycle|
        device_id = "memleak-heartbeat-#{cycle % 10}"
        ConnectionMonitor.register(device_id, connection_type: 'device')
        HeartbeatMonitor.process_heartbeat(device_id, { battery: 80 })
        ConnectionMonitor.touch(device_id)

        if cycle % 10 == 9
          # Periodic cleanup like production
          10.times { |j| ConnectionMonitor.unregister("memleak-heartbeat-#{j}") }
          GC.start
          samples << current_memory_rss
        end
      end

      # Verify memory growth trend is bounded
      return if samples.size < 3

      growth = samples.last - initial_memory
      avg_growth_per_cycle = growth.to_f / samples.size

      expect(avg_growth_per_cycle).to be < ACCEPTABLE_GROWTH_PER_CYCLE,
        "Memory growing at #{(avg_growth_per_cycle / 1024).round(1)}KB/cycle"
    end
  end

  describe 'Repeated command cycles' do
    it 'does not leak memory across command create/resolve cycles' do
      GC.start
      initial_memory = current_memory_rss

      100.times do |i|
        cmd = PendingCommand.create!(
          smartphone: @device,
          request_id: SecureRandom.uuid,
          command: 'get_contacts',
          status: :pending
        )
        cmd.update!(status: :completed, completed_at: Time.current)

        if i % 25 == 24
          GC.start
        end
      end

      GC.start
      final_memory = current_memory_rss
      growth_mb = (final_memory - initial_memory) / (1024.0 * 1024.0)

      # Allow up to 25MB for GC variance and ActiveRecord caching
      expect(growth_mb).to be < 25, "Memory grew #{growth_mb.round(2)}MB over 100 command cycles"
    end
  end

  describe 'File upload/download cycles' do
    after(:each) do
      FileUtils.rm_rf(Dir.glob(File.join(Rails.root, 'tmp', 'chunks', 'memleak-*')))
      FileUtils.rm_rf(Dir.glob(File.join(Rails.root, 'tmp', 'assembled', 'memleak-*')))
    end

    it 'does not leak memory across upload cycles' do
      GC.start
      initial_memory = current_memory_rss

      20.times do |i|
        upload_id = "memleak-upload-#{SecureRandom.hex(8)}"
        chunk_data = 'A' * 10_000 # 10KB

        3.times do |chunk_idx|
          chunk_io = StringIO.new(chunk_data)
          service = ResumableUploadService.new(
            upload_id: upload_id,
            chunk_number: chunk_idx,
            total_chunks: 3,
            chunk_data: chunk_io,
            filename: "memleak_test_#{i}.bin"
          )
          service.call
        end

        # Clean up assembled file
        assembled_path = File.join(Rails.root, 'tmp', 'assembled')
        FileUtils.rm_rf(Dir.glob(File.join(assembled_path, "#{upload_id}_*")))

        GC.start if i % 5 == 4
      end

      GC.start
      final_memory = current_memory_rss
      growth_mb = (final_memory - initial_memory) / (1024.0 * 1024.0)

      expect(growth_mb).to be < 30, "Memory grew #{growth_mb.round(2)}MB over 20 upload cycles"
    end
  end

  describe 'Memory growth tracking utility' do
    it 'tracks memory across measured blocks' do
      measurements = []

      5.times do |i|
        GC.start
        before = current_memory_rss

        # Simulate work
        data = Array.new(1000) { { id: SecureRandom.uuid, payload: 'x' * 100 } }
        data.clear

        GC.start
        after = current_memory_rss

        measurements << {
          cycle: i,
          before: before,
          after: after,
          delta: after - before
        }
      end

      # Verify measurement structure
      expect(measurements.size).to eq(5)
      measurements.each do |m|
        expect(m).to include(:cycle, :before, :after, :delta)
      end
    end
  end

  private

  def current_memory_rss
    if Gem.win_platform?
      pid = Process.pid
      output = `tasklist /FI "PID eq #{pid}" /FO CSV /NH 2>NUL`.strip
      match = output.match(/"([\d,]+)\s*K"/)
      match ? match[1].delete(',').to_i * 1024 : 0
    else
      `ps -o rss= -p #{Process.pid}`.strip.to_i * 1024
    end
  rescue StandardError
    0
  end
end
