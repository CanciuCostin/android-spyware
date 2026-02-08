class PartitionKeylogs < ActiveRecord::Migration[6.0]
  # This migration implements table partitioning for keylogs
  # WARNING: This is a major operation that may take significant time on large tables
  # Consider running during maintenance window
  
  def up
    # Only proceed if table has significant data (>100k rows)
    row_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM keylogs")
    
    if row_count < 100_000
      say "Skipping partitioning: keylogs table has only #{row_count} rows (threshold: 100,000)"
      return
    end
    
    say_with_time "Creating partitioned keylogs table (#{row_count} rows)..." do
      # Step 1: Create the partitioned table structure
      execute <<-SQL
        CREATE TABLE keylogs_partitioned (
          LIKE keylogs INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES
        ) PARTITION BY RANGE (created_at);
      SQL
      
      # Step 2: Create partitions for current month and next 6 months
      create_partitions_for_range(Date.today.beginning_of_month, 6)
      
      # Step 3: Create a default partition for older data
      execute <<-SQL
        CREATE TABLE keylogs_default PARTITION OF keylogs_partitioned DEFAULT;
      SQL
      
      # Step 4: Copy indexes from original table (excluding primary key)
      copy_indexes_to_partitioned_table
      
      # Step 5: Copy data (this will take time - progress shown)
      say "Copying #{row_count} rows to partitioned table... This may take several minutes."
      execute <<-SQL
        INSERT INTO keylogs_partitioned 
        SELECT * FROM keylogs;
      SQL
      
      # Step 6: Rename tables (atomic swap)
      execute <<-SQL
        ALTER TABLE keylogs RENAME TO keylogs_old;
        ALTER TABLE keylogs_partitioned RENAME TO keylogs;
      SQL
      
      # Step 7: Recreate foreign keys
      execute <<-SQL
        ALTER TABLE keylogs 
        ADD CONSTRAINT fk_rails_keylogs_smartphone 
        FOREIGN KEY (smartphone_id) REFERENCES smartphones(id);
      SQL
      
      say "✓ Partitioning complete. Old table preserved as keylogs_old"
      say "  Run 'DROP TABLE keylogs_old;' after verifying data integrity"
    end
  end
  
  def down
    say_with_time "Rolling back partitioning..." do
      if table_exists?(:keylogs_old)
        execute "DROP TABLE IF EXISTS keylogs;"
        execute "ALTER TABLE keylogs_old RENAME TO keylogs;"
        say "✓ Restored original keylogs table"
      else
        say "WARNING: Cannot rollback - keylogs_old not found. Manual intervention required."
      end
    end
  end
  
  private
  
  def create_partitions_for_range(start_date, months_ahead)
    months_ahead.times do |i|
      partition_start = start_date + i.months
      partition_end = start_date + (i + 1).months
      partition_name = "keylogs_#{partition_start.strftime('%Y_%m')}"
      
      execute <<-SQL
        CREATE TABLE #{partition_name} PARTITION OF keylogs_partitioned
        FOR VALUES FROM ('#{partition_start}') TO ('#{partition_end}');
      SQL
      
      say "  ✓ Created partition: #{partition_name}"
    end
  end
  
  def copy_indexes_to_partitioned_table
    # Note: Partition-wise indexes are automatically created
    # This method is a placeholder for custom index logic if needed
  end
end
