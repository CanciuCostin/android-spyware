# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Load Testing', type: :performance do
  # Deterministic device IDs for reproducibility
  let(:device_id_prefix) { 'load-test-device' }

  before(:all) do
    @devices = []
    5.times do |i|
      @devices << create(:smartphone, device_id: "load-test-base-#{i}")
    end
  end

  after(:all) do
    Smartphone.where('device_id LIKE ?', 'load-test-%').destroy_all
  end

  describe 'Concurrent device connections' do
    it 'handles 100+ device registrations without errors' do
      errors = []

      time = Benchmark.realtime do
        threads = 100.times.map do |i|
          Thread.new do
            device_id = "#{device_id_prefix}-#{i}"
            ConnectionMonitor.register(device_id, connection_type: 'device')
          rescue StandardError => e
            errors << "Device #{i}: #{e.message}"
          end
        end
        threads.each(&:join)
      end

      # Clean up registered devices
      100.times { |i| ConnectionMonitor.unregister("#{device_id_prefix}-#{i}") }

      expect(errors).to be_empty, "Errors during registration: #{errors.join(', ')}"
      expect(time).to be < 10.0, "Registration took #{time.round(2)}s (expected < 10s)"
    end

    it 'maintains connection state under concurrent access' do
      device_ids = 50.times.map { |i| "#{device_id_prefix}-state-#{i}" }

      # Register all devices
      device_ids.each { |id| ConnectionMonitor.register(id, connection_type: 'device') }

      # Concurrent touch operations
      time = Benchmark.realtime do
        threads = device_ids.map do |id|
          Thread.new do
            10.times { ConnectionMonitor.touch(id) }
          end
        end
        threads.each(&:join)
      end

      # Verify all devices still registered
      stats = ConnectionMonitor.statistics
      expect(stats[:total_connections]).to be >= 50

      # Clean up
      device_ids.each { |id| ConnectionMonitor.unregister(id) }

      expect(time).to be < 15.0, "Concurrent touches took #{time.round(2)}s"
    end
  end

  describe 'Command response times under load' do
    before do
      @test_device = @devices.first
    end

    it 'creates commands within acceptable time under concurrent load' do
      times = []

      threads = 20.times.map do
        Thread.new do
          5.times do
            t = Benchmark.realtime do
              PendingCommand.create!(
                smartphone: @test_device,
                request_id: SecureRandom.uuid,
                command: 'get_contacts',
                status: :pending
              )
            end
            times << t
          end
        end
      end
      threads.each(&:join)

      avg_time = times.sum / times.size
      max_time = times.max
      p95_time = times.sort[(times.size * 0.95).to_i]

      expect(avg_time).to be < 0.1, "Avg command creation: #{avg_time.round(4)}s (expected < 0.1s)"
      expect(p95_time).to be < 0.5, "P95 command creation: #{p95_time.round(4)}s (expected < 0.5s)"
    end

    it 'resolves commands efficiently under load' do
      commands = 50.times.map do
        PendingCommand.create!(
          smartphone: @test_device,
          request_id: SecureRandom.uuid,
          command: 'get_contacts',
          status: :pending
        )
      end

      time = Benchmark.realtime do
        threads = commands.map do |cmd|
          Thread.new do
            cmd.update!(status: :completed, completed_at: Time.current)
          end
        end
        threads.each(&:join)
      end

      expect(time).to be < 5.0, "Resolving 50 commands took #{time.round(2)}s"
    end
  end

  describe 'Dashboard rendering with many devices' do
    before(:all) do
      @dashboard_devices = create_list(:smartphone, 20, device_id: nil)
      @dashboard_devices.each_with_index do |d, i|
        d.update_column(:device_id, "dash-device-#{i}")
        create_list(:keylog, 10, smartphone: d)
        create_list(:pending_command, 5, smartphone: d, status: :pending)
      end
    end

    after(:all) do
      Smartphone.where('device_id LIKE ?', 'dash-device-%').destroy_all
    end

    it 'loads device dashboard data within acceptable time' do
      time = Benchmark.realtime do
        OptimizedQueries.device_dashboard
      end

      expect(time).to be < 2.0, "Dashboard query took #{time.round(3)}s (expected < 2s)"
    end

    it 'loads paginated device list efficiently' do
      time = Benchmark.realtime do
        Smartphone.includes(:apk_installation)
                  .order(created_at: :desc)
                  .limit(25)
                  .offset(0)
                  .to_a
      end

      expect(time).to be < 0.5, "Paginated list took #{time.round(3)}s (expected < 0.5s)"
    end

    it 'aggregates statistics across devices efficiently' do
      time = Benchmark.realtime do
        {
          total_devices: Smartphone.count,
          total_keylogs: Keylog.count,
          pending_commands: PendingCommand.where(status: :pending).count,
          recent_activity: Smartphone.where('updated_at > ?', 24.hours.ago).count
        }
      end

      expect(time).to be < 1.0, "Stats aggregation took #{time.round(3)}s (expected < 1s)"
    end
  end

  describe 'Memory usage tracking' do
    it 'does not leak memory during bulk device operations' do
      initial_rss = current_memory_rss

      100.times do |i|
        device_id = "mem-test-#{i}"
        ConnectionMonitor.register(device_id, connection_type: 'device')
        ConnectionMonitor.touch(device_id)
        ConnectionMonitor.unregister(device_id)
      end

      GC.start
      final_rss = current_memory_rss
      growth_mb = (final_rss - initial_rss) / (1024.0 * 1024.0)

      # Allow up to 50MB growth for GC variance
      expect(growth_mb).to be < 50, "Memory grew by #{growth_mb.round(2)}MB"
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
