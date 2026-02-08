namespace :db do
  namespace :maintenance do
    desc "Run full database maintenance (vacuum, analyze, refresh views)"
    task full: :environment do
      puts "\n🔧 Database Maintenance Started\n"
      puts "=" * 80
      
      # Vacuum analyze all tables
      Rake::Task['db:maintenance:vacuum_analyze'].invoke
      
      # Refresh materialized views
      Rake::Task['db:maintenance:refresh_views'].invoke
      
      # Check for unused indexes
      Rake::Task['db:maintenance:check_indexes'].invoke
      
      puts "=" * 80
      puts "✓ Database maintenance complete\n"
    end
    
    desc "Vacuum and analyze all tables"
    task vacuum_analyze: :environment do
      puts "\n🧹 Running VACUUM ANALYZE..."
      
      tables = ActiveRecord::Base.connection.tables.reject { |t| t =~ /^ar_internal_metadata|schema_migrations/ }
      
      tables.each do |table|
        print "  Vacuuming #{table}..."
        start_time = Time.current
        
        ActiveRecord::Base.connection.execute("VACUUM ANALYZE #{table}")
        
        duration = Time.current - start_time
        puts " ✓ (#{duration.round(2)}s)"
      end
      
      puts "  ✓ All tables vacuumed and analyzed"
    end
    
    desc "Refresh all materialized views"
    task refresh_views: :environment do
      puts "\n🔄 Refreshing materialized views..."
      
      views = ['device_summaries_cached']
      
      views.each do |view|
        print "  Refreshing #{view}..."
        start_time = Time.current
        
        begin
          ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW #{view}")
          duration = Time.current - start_time
          puts " ✓ (#{duration.round(2)}s)"
        rescue StandardError => e
          puts " ✗ (#{e.message})"
        end
      end
    end
    
    desc "Check for unused indexes"
    task check_indexes: :environment do
      puts "\n📊 Checking index usage..."
      
      unused = OptimizedQueries.index_usage_stats.select { |idx| idx['usage_level'] == 'UNUSED' }
      
      if unused.empty?
        puts "  ✓ All indexes are being used"
      else
        puts "  ⚠ Found #{unused.count} unused indexes:"
        unused.each do |idx|
          puts "    - #{idx['tablename']}.#{idx['indexname']} (#{idx['index_size']})"
        end
        puts "\n  Consider dropping unused indexes to save space"
      end
    end
    
    desc "Generate database performance report"
    task performance_report: :environment do
      puts "\n📈 Database Performance Report\n"
      puts "=" * 80
      
      # Table sizes
      puts "\n📦 Table Sizes (Top 10):"
      OptimizedQueries.table_statistics.first(10).each do |stat|
        printf "  %-30s  %12s\n", stat['tablename'], stat['total_size']
      end
      
      # Connection pool stats
      puts "\n🔌 Connection Pool:"
      pool_stats = OptimizedQueries.connection_pool_stats
      puts "  Size: #{pool_stats[:size]}"
      puts "  Active: #{pool_stats[:busy_connections]}"
      puts "  Idle: #{pool_stats[:idle_connections]}"
      puts "  Waiting: #{pool_stats[:waiting_threads]}"
      
      # Slow queries
      puts "\n🐌 Slow Queries (Top 10):"
      slow = OptimizedQueries.slow_queries(min_duration_ms: 100, limit: 10)
      if slow.empty?
        puts "  ✓ No slow queries found (or pg_stat_statements not enabled)"
      else
        slow.each do |query|
          puts "  #{query['mean_exec_time'].round(2)}ms - #{query['query'].truncate(80)}"
        end
      end
      
      # Missing index suggestions
      puts "\n💡 Missing Index Suggestions:"
      suggestions = OptimizedQueries.missing_index_suggestions
      high_priority = suggestions.select { |s| s['recommendation']&.include?('HIGH') }
      
      if high_priority.empty?
        puts "  ✓ No high-priority index suggestions"
      else
        high_priority.first(5).each do |suggestion|
          puts "  #{suggestion['tablename']} - #{suggestion['recommendation']}"
          puts "    Sequential scans: #{suggestion['sequential_scans']}, Rows: #{suggestion['rows_read']}"
        end
      end
      
      puts "=" * 80
    end
    
    desc "Create database backup"
    task backup: :environment do
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      db_config = ActiveRecord::Base.connection_db_config.configuration_hash
      
      backup_file = "backup/db_#{timestamp}.sql"
      
      puts "📦 Creating database backup..."
      puts "  Database: #{db_config[:database]}"
      puts "  File: #{backup_file}"
      
      FileUtils.mkdir_p('backup')
      
      cmd = "pg_dump -h #{db_config[:host]} -U #{db_config[:username]} #{db_config[:database]} > #{backup_file}"
      system(cmd)
      
      if $?.success?
        file_size = File.size(backup_file) / (1024.0 * 1024.0)
        puts "  ✓ Backup complete (#{file_size.round(2)} MB)"
      else
        puts "  ✗ Backup failed"
      end
    end
    
    desc "Analyze database bloat"
    task check_bloat: :environment do
      puts "\n💨 Checking table bloat...\n"
      
      bloat_query = <<-SQL
        SELECT
          schemaname, tablename,
          pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
          ROUND(100 * pg_total_relation_size(schemaname||'.'||tablename) / 
                NULLIF(pg_database_size(current_database()), 0), 2) AS pct_of_db
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT 10;
      SQL
      
      results = ActiveRecord::Base.connection.execute(bloat_query)
      
      results.each do |row|
        printf "  %-30s  %12s  (%s%% of DB)\n", 
               row['tablename'], 
               row['size'], 
               row['pct_of_db']
      end
      
      puts "\n  💡 Run 'rake db:maintenance:vacuum_analyze' to reduce bloat"
    end
    
    desc "Optimize all tables (FULL VACUUM - requires downtime)"
    task optimize_tables: :environment do
      puts "\n⚠️  WARNING: VACUUM FULL requires table locks (downtime)\n"
      print "Continue? (yes/no): "
      
      response = STDIN.gets.chomp
      unless response.downcase == 'yes'
        puts "Cancelled"
        exit
      end
      
      tables = ['keylogs', 'geo_locations', 'sms_messages', 'call_logs', 'pending_commands']
      
      tables.each do |table|
        puts "  Optimizing #{table}..."
        ActiveRecord::Base.connection.execute("VACUUM FULL #{table}")
        puts "  ✓ #{table} optimized"
      end
      
      puts "\n✓ Table optimization complete"
    end
    
    desc "Reset query statistics"
    task reset_stats: :environment do
      puts "🔄 Resetting pg_stat_statements..."
      
      begin
        ActiveRecord::Base.connection.execute("SELECT pg_stat_statements_reset()")
        puts "  ✓ Statistics reset"
      rescue StandardError => e
        puts "  ✗ Failed: #{e.message}"
      end
    end
  end
end
