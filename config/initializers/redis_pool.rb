# frozen_string_literal: true

require 'connection_pool'

# Redis connection pool for efficient connection management
# Prevents connection leaks by reusing connections across requests
module RedisPool
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  
  # Connection pool size matches Puma threads + buffer
  # Increased from 7 to 15 for better concurrency (5 threads + 10 buffer)
  # Adjust based on concurrency needs (Puma threads, Sidekiq workers, etc.)
  POOL_SIZE = ENV.fetch('REDIS_POOL_SIZE', ENV.fetch('RAILS_MAX_THREADS', 5).to_i + 10).to_i
  
  POOL = ConnectionPool.new(size: POOL_SIZE, timeout: 5) do
    Redis.new(url: REDIS_URL)
  end

  # Helper to execute Redis commands with pooled connection
  # Usage: RedisPool.with { |redis| redis.get('key') }
  def self.with(&block)
    POOL.with(&block)
  end
end