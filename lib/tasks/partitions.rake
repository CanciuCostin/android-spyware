namespace :db do
  namespace :partitions do
    desc "Create next month's partitions for all partitioned tables"
    task create_monthly: :environment do
      next_month = 1.month.from_now.beginning_of_month
      month_after = 2.months.from_now.beginning_of_month
      
      partition_name = "keylogs_#{next_month.strftime('%Y_%m')}"
      
      begin
        # Check if partition already exists
        exists = ActiveRecord::Base.connection.select_value(<<-SQL)
          SELECT COUNT(*) FROM pg_tables 
          WHERE schemaname = 'public' 
          AND tablename = '#{partition_name}'
        SQL
        
        if exists.to_i > 0
          puts "⚠ Partition #{partition_name} already exists"
        else
          ActiveRecord::Base.connection.execute(<<-SQL)
            CREATE TABLE IF NOT EXISTS #{partition_name} 
            PARTITION OF keylogs
            FOR VALUES FROM ('#{next_month.to_date}') TO ('#{month_after.to_date}');
          SQL
          
          puts "✓ Created partition: #{partition_name} (#{next_month.strftime('%b %Y')})"
        end
      rescue StandardError => e
        puts "✗ Error creating partition: #{e.message}"
        raise
      end
    end
    
    desc "Create partitions for the next N months (default: 3)"
    task :create_future, [:months] => :environment do |t, args|
      months = (args[:months] || 3).to_i
      
      puts "Creating partitions for next #{months} months..."
      
      months.times do |i|
        offset = i + 1
        partition_start = offset.months.from_now.beginning_of_month
        partition_end = (offset + 1).months.from_now.beginning_of_month
        partition_name = "keylogs_#{partition_start.strftime('%Y_%m')}"
        
        exists = ActiveRecord::Base.connection.select_value(<<-SQL)
          SELECT COUNT(*) FROM pg_tables 
          WHERE schemaname = 'public' 
          AND tablename = '#{partition_name}'
        SQL
        
        if exists.to_i > 0
          puts "  ⊙ #{partition_name} already exists"
          next
        end
        
        ActiveRecord::Base.connection.execute(<<-SQL)
          CREATE TABLE IF NOT EXISTS #{partition_name} 
          PARTITION OF keylogs
          FOR VALUES FROM ('#{partition_start.to_date}') TO ('#{partition_end.to_date}');
        SQL
        
        puts "  ✓ Created #{partition_name}"
      end
      
      puts "✓ Partition creation complete"
    end
    
    desc "Drop partitions older than N months (default: 6)"
    task :cleanup_old, [:retention_months] => :environment do |t, args|
      retention_months = (args[:retention_months] || 6).to_i
      cutoff = retention_months.months.ago.beginning_of_month
      
      puts "Cleaning up partitions older than #{cutoff.strftime('%Y-%m')}..."
      
      # Find old partitions
      partitions = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename LIKE 'keylogs_____%%'
        AND tablename < 'keylogs_#{cutoff.strftime('%Y_%m')}'
        ORDER BY tablename
      SQL
      
      if partitions.count == 0
        puts "✓ No old partitions to clean up"
        return
      end
      
      partitions.each do |row|
        table_name = row['tablename']
        
        # Get row count before dropping
        row_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table_name}")
        
        puts "  Dropping #{table_name} (#{row_count} rows)..."
        ActiveRecord::Base.connection.execute("DROP TABLE #{table_name}")
        puts "  ✓ Dropped #{table_name}"
      end
      
      puts "✓ Cleanup complete (#{partitions.count} partitions removed)"
    end
    
    desc "List all keylogs partitions with statistics"
    task list: :environment do
      puts "\n📊 Keylogs Partitions\n"
      puts "=" * 80
      
      partitions = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          c.relname AS partition_name,
          pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
          (SELECT COUNT(*) FROM ONLY information_schema.tables WHERE table_name = c.relname) as exists
        FROM pg_class c
        JOIN pg_inherits i ON i.inhrelid = c.oid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'keylogs'
        ORDER BY c.relname;
      SQL
      
      if partitions.count == 0
        puts "  ⚠ No partitions found (table might not be partitioned)"
        return
      end
      
      total_size = 0
      partitions.each do |row|
        partition_name = row['partition_name']
        size = row['size']
        
        # Get row count for each partition
        row_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{partition_name}")
        
        printf "  %-30s  %12s rows  %10s\n", partition_name, row_count.to_s.rjust(12), size
      end
      
      puts "=" * 80
      puts "  Total partitions: #{partitions.count}"
    end
    
    desc "Archive old partition data to separate archive table"
    task :archive_old, [:retention_months] => :environment do |t, args|
      retention_months = (args[:retention_months] || 6).to_i
      cutoff = retention_months.months.ago.beginning_of_month
      
      puts "Archiving partitions older than #{cutoff.strftime('%Y-%m')}..."
      
      # Create archive table if it doesn't exist
      unless ActiveRecord::Base.connection.table_exists?(:keylogs_archive)
        ActiveRecord::Base.connection.execute(<<-SQL)
          CREATE TABLE keylogs_archive (LIKE keylogs INCLUDING ALL);
        SQL
        puts "  ✓ Created keylogs_archive table"
      end
      
      # Find old partitions
      partitions = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename LIKE 'keylogs_____%%'
        AND tablename < 'keylogs_#{cutoff.strftime('%Y_%m')}'
        ORDER BY tablename
      SQL
      
      if partitions.count == 0
        puts "✓ No partitions to archive"
        return
      end
      
      partitions.each do |row|
        table_name = row['tablename']
        
        puts "  Archiving #{table_name}..."
        ActiveRecord::Base.connection.execute(<<-SQL)
          INSERT INTO keylogs_archive 
          SELECT * FROM #{table_name};
        SQL
        
        puts "  ✓ Archived #{table_name}"
      end
      
      puts "✓ Archive complete (#{partitions.count} partitions archived)"
      puts "  Run 'rake db:partitions:cleanup_old' to remove archived partitions"
    end
    
    desc "Verify partition integrity and coverage"
    task verify: :environment do
      puts "\n🔍 Verifying Partition Integrity\n"
      puts "=" * 80
      
      # Check if keylogs is partitioned
      is_partitioned = ActiveRecord::Base.connection.select_value(<<-SQL)
        SELECT COUNT(*) FROM pg_partitioned_table 
        WHERE partrelid = 'keylogs'::regclass
      SQL
      
      if is_partitioned.to_i == 0
        puts "  ⚠ keylogs table is NOT partitioned"
        return
      end
      
      puts "  ✓ keylogs table is partitioned"
      
      # Check for gaps in partition coverage
      partitions = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          c.relname AS partition_name,
          pg_get_expr(c.relpartbound, c.oid) AS partition_bounds
        FROM pg_class c
        JOIN pg_inherits i ON i.inhrelid = c.oid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'keylogs'
        AND c.relname != 'keylogs_default'
        ORDER BY c.relname;
      SQL
      
      puts "  ✓ Found #{partitions.count} partitions"
      
      # Check if default partition exists
      has_default = ActiveRecord::Base.connection.select_value(<<-SQL)
        SELECT COUNT(*) FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'keylogs_default'
      SQL
      
      if has_default.to_i > 0
        default_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM keylogs_default")
        puts "  ✓ Default partition exists (#{default_count} rows)"
        
        if default_count.to_i > 0
          puts "    ⚠ Warning: Default partition contains data - consider creating missing partitions"
        end
      else
        puts "  ⚠ No default partition - records outside range will fail to insert"
      end
      
      # Check for future coverage
      current_month = Date.today.beginning_of_month
      next_3_months = [1, 2, 3].map { |i| current_month + i.months }
      
      puts "\n  Future Coverage:"
      next_3_months.each do |month|
        partition_name = "keylogs_#{month.strftime('%Y_%m')}"
        exists = ActiveRecord::Base.connection.select_value(<<-SQL)
          SELECT COUNT(*) FROM pg_tables 
          WHERE schemaname = 'public' 
          AND tablename = '#{partition_name}'
        SQL
        
        status = exists.to_i > 0 ? "✓" : "✗"
        puts "    #{status} #{month.strftime('%B %Y')} (#{partition_name})"
      end
      
      puts "=" * 80
    end
  end
end
