# Query performance monitoring and logging
# Logs slow queries and tracks database performance metrics

if Rails.env.production? || Rails.env.development?
  # Log slow queries (> 1 second in production, > 500ms in development)
  slow_query_threshold = Rails.env.production? ? 1000 : 500
  
  ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    duration = (finish - start) * 1000 # Convert to milliseconds
    
    if duration > slow_query_threshold
      sql = payload[:sql]
      binds = payload[:binds]
      name = payload[:name]
      
      # Skip SCHEMA queries and internal Rails queries
      next if sql.match?(/^(SCHEMA|EXPLAIN|BEGIN|COMMIT|ROLLBACK|SAVEPOINT)/)
      next if name == 'CACHE'
      
      Rails.logger.warn({
        message: "SLOW QUERY",
        duration_ms: duration.round(2),
        sql: sql.truncate(500),
        binds: binds&.map(&:value),
        name: name,
        backtrace: Rails.backtrace_cleaner.clean(caller).first(3)
      }.to_json)
      
      # Optionally send to monitoring service (e.g., DataDog, New Relic)
      # Metrics.increment('database.slow_queries', tags: ["threshold:#{slow_query_threshold}"])
    end
  end
  
  Rails.logger.info "Query performance monitoring enabled (threshold: #{slow_query_threshold}ms)"
end

# Connection pool monitoring
if Rails.env.production?
  # Log connection pool exhaustion warnings
  ActiveSupport::Notifications.subscribe('checkout.active_record') do |name, start, finish, id, payload|
    wait_time = (finish - start) * 1000
    
    if wait_time > 500 # Waited more than 500ms for a connection
      Rails.logger.warn({
        message: "CONNECTION POOL WAIT",
        wait_time_ms: wait_time.round(2),
        pool_size: ActiveRecord::Base.connection_pool.size,
        busy_connections: ActiveRecord::Base.connection_pool.connections.count { |c| c.in_use? }
      }.to_json)
    end
  end
end

# Enable pg_stat_statements extension for query analytics (PostgreSQL only)
if Rails.env.production? && defined?(ActiveRecord::Base)
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    begin
      conn.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")
      Rails.logger.info "pg_stat_statements extension enabled"
    rescue StandardError => e
      Rails.logger.warn "Could not enable pg_stat_statements: #{e.message}"
    end
  end
end

# Query result caching for ActiveRecord
if Rails.env.production?
  # Enable query caching globally
  ActiveRecord::Base.connection.enable_query_cache!
  
  Rails.logger.info "Query result caching enabled"
end
