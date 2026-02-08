require 'rails_helper'
require 'benchmark'

RSpec.describe 'Database Performance Benchmarks' do
  # Create test data once for all specs
  before(:all) do
    @device = create(:smartphone)
    @devices = create_list(:smartphone, 10)
  end
  
  after(:all) do
    Smartphone.destroy_all
  end
  
  describe 'Keylog queries' do
    before(:all) do
      # Create test keylogs
      create_list(:keylog, 1000, smartphone: @device)
    end
    
    it 'fetches recent keylogs efficiently' do
      time = Benchmark.realtime do
        @device.keylogs.where('created_at > ?', 1.day.ago).limit(100).to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
    
    it 'filters by app efficiently with index' do
      time = Benchmark.realtime do
        Keylog.where(app_package: 'com.example.app', smartphone_id: @device.id).limit(50).to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
    
    it 'counts recent keylogs efficiently' do
      time = Benchmark.realtime do
        @device.keylogs.where('created_at > ?', 7.days.ago).count
      end
      
      expect(time).to be < 0.2, "Count query took #{time.round(3)}s (expected < 0.2s)"
    end
  end
  
  describe 'Device summary queries' do
    before(:all) do
      @devices.each do |device|
        create_list(:keylog, 100, smartphone: device)
        create_list(:geo_location, 50, smartphone: device)
        create_list(:sms_message, 30, smartphone: device)
      end
    end
    
    it 'loads device with associations efficiently' do
      time = Benchmark.realtime do
        Smartphone.includes(:keylogs, :geo_locations, :sms_messages)
                  .where('keylogs.created_at > ?', 1.day.ago)
                  .references(:keylogs)
                  .limit(10)
                  .to_a
      end
      
      expect(time).to be < 0.5, "Query took #{time.round(3)}s (expected < 0.5s)"
    end
    
    it 'fetches cached device summary quickly' do
      # Warm up cache
      @device.summary_cached
      
      time = Benchmark.realtime do
        10.times { @device.summary_cached }
      end
      
      avg_time = time / 10
      expect(avg_time).to be < 0.01, "Cached query took #{avg_time.round(4)}s (expected < 0.01s)"
    end
  end
  
  describe 'Command queue queries' do
    before(:all) do
      create_list(:pending_command, 500, smartphone: @device, status: :pending)
      create_list(:pending_command, 500, smartphone: @device, status: :completed)
    end
    
    it 'fetches pending commands efficiently' do
      time = Benchmark.realtime do
        @device.pending_commands.where(status: :pending).limit(100).to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
    
    it 'uses composite index for device + status' do
      time = Benchmark.realtime do
        PendingCommand.where(smartphone_id: @device.id, status: :pending)
                     .order(created_at: :desc)
                     .limit(50)
                     .to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
  end
  
  describe 'Geolocation queries' do
    before(:all) do
      create_list(:geo_location, 1000, smartphone: @device)
    end
    
    it 'fetches recent locations efficiently' do
      time = Benchmark.realtime do
        @device.geo_locations.where('created_at > ?', 1.day.ago)
               .order(created_at: :desc)
               .limit(100)
               .to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
  end
  
  describe 'Notification queries' do
    before(:all) do
      create_list(:device_notification, 500, device_id: @device.device_id)
    end
    
    it 'fetches recent notifications efficiently' do
      time = Benchmark.realtime do
        DeviceNotification.where(device_id: @device.device_id)
                         .where('received_at > ?', 1.day.ago)
                         .order(received_at: :desc)
                         .limit(100)
                         .to_a
      end
      
      expect(time).to be < 0.1, "Query took #{time.round(3)}s (expected < 0.1s)"
    end
  end
  
  describe 'Bulk operations' do
    it 'batch inserts keylogs efficiently' do
      keylogs = 1000.times.map do |i|
        {
          smartphone_id: @device.id,
          device_id: @device.device_id,
          keystroke: "test#{i}",
          app_package: 'com.test.app',
          app_name: 'Test App',
          event_type: 'TEXT_CHANGED',
          client_timestamp: Time.current.to_i * 1000,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      time = Benchmark.realtime do
        Keylog.insert_all(keylogs)
      end
      
      expect(time).to be < 1.0, "Batch insert took #{time.round(3)}s (expected < 1.0s)"
    end
    
    it 'batch processes records efficiently' do
      count = 0
      
      time = Benchmark.realtime do
        Keylog.where(smartphone_id: @device.id)
              .find_each(batch_size: 1000) do |keylog|
          count += 1
        end
      end
      
      expect(time).to be < 2.0, "Batch processing took #{time.round(3)}s (expected < 2.0s)"
    end
  end
  
  describe 'Index utilization' do
    it 'uses index for device_id lookups' do
      # Check query plan
      plan = ActiveRecord::Base.connection.execute(
        "EXPLAIN SELECT * FROM keylogs WHERE smartphone_id = #{@device.id}"
      ).to_a
      
      plan_text = plan.map { |row| row['QUERY PLAN'] }.join("\n")
      
      # Should use index scan, not sequential scan
      expect(plan_text).to match(/Index Scan/i)
      expect(plan_text).not_to match(/Seq Scan/i)
    end
    
    it 'uses composite index for device + time queries' do
      plan = ActiveRecord::Base.connection.execute(
        "EXPLAIN SELECT * FROM keylogs 
         WHERE smartphone_id = #{@device.id} 
         AND created_at > NOW() - INTERVAL '1 day'"
      ).to_a
      
      plan_text = plan.map { |row| row['QUERY PLAN'] }.join("\n")
      
      expect(plan_text).to match(/Index/i)
    end
  end
  
  describe 'Connection pool performance' do
    it 'handles concurrent queries efficiently' do
      time = Benchmark.realtime do
        threads = 10.times.map do
          Thread.new do
            Smartphone.find(@device.id)
            @device.keylogs.limit(10).to_a
          end
        end
        
        threads.each(&:join)
      end
      
      expect(time).to be < 1.0, "Concurrent queries took #{time.round(3)}s (expected < 1.0s)"
    end
  end
  
  describe 'Performance monitoring utilities' do
    it 'retrieves table statistics quickly' do
      time = Benchmark.realtime do
        OptimizedQueries.table_statistics
      end
      
      expect(time).to be < 1.0, "Stats query took #{time.round(3)}s"
    end
    
    it 'retrieves index usage stats quickly' do
      time = Benchmark.realtime do
        OptimizedQueries.index_usage_stats
      end
      
      expect(time).to be < 1.0, "Stats query took #{time.round(3)}s"
    end
    
    it 'retrieves connection pool stats instantly' do
      stats = OptimizedQueries.connection_pool_stats
      
      expect(stats).to include(:size, :connections, :busy_connections, :idle_connections)
      expect(stats[:size]).to be > 0
    end
  end
end
