class CreateDatabaseViews < ActiveRecord::Migration[6.0]
  def up
    say_with_time "Creating optimized database views..." do
      
      # Device summaries view
      execute OptimizedQueries.device_summary_view_sql
      say "  ✓ Created device_summaries view"
      
      # Keylog app statistics view
      execute OptimizedQueries.keylog_app_stats_view_sql
      say "  ✓ Created keylog_app_stats view"
      
      # Command queue health view
      execute OptimizedQueries.command_queue_health_view_sql
      say "  ✓ Created command_queue_health view"
      
      # Create materialized view for device summaries (faster, needs refresh)
      execute <<-SQL
        CREATE MATERIALIZED VIEW device_summaries_cached AS
        SELECT * FROM device_summaries;
        
        CREATE UNIQUE INDEX ON device_summaries_cached (id);
      SQL
      say "  ✓ Created device_summaries_cached materialized view"
      
      say "  📝 Refresh materialized view with: REFRESH MATERIALIZED VIEW device_summaries_cached;"
    end
  end
  
  def down
    say_with_time "Dropping database views..." do
      execute "DROP MATERIALIZED VIEW IF EXISTS device_summaries_cached"
      execute "DROP VIEW IF EXISTS command_queue_health"
      execute "DROP VIEW IF EXISTS keylog_app_stats"
      execute "DROP VIEW IF EXISTS device_summaries"
      say "  ✓ All views dropped"
    end
  end
end
