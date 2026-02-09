# frozen_string_literal: true

# Cache store configuration for Rails models and views.
# Uses Redis (via RedisPool) in production/staging, memory store otherwise.

Rails.application.configure do
  redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  default_ttl = ENV.fetch('CACHE_DEFAULT_TTL', 300).to_i # 5 minutes

  if Rails.env.production? || Rails.env.staging?
    config.cache_store = :redis_cache_store, {
      url: redis_url,
      expires_in: default_ttl.seconds,
      namespace: "eaglespy:#{Rails.env}",
      pool_size: ENV.fetch('REDIS_POOL_SIZE', ENV.fetch('RAILS_MAX_THREADS', 5).to_i + 5).to_i,
      pool_timeout: 5,
      connect_timeout: 2,
      read_timeout: 1,
      write_timeout: 1,
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.error "[Cache] #{method} failed: #{exception.class} - #{exception.message}"
        # Optionally report to error tracking (Sentry, Datadog, etc.)
      }
    }
  elsif Rails.env.development?
    # Use memory store with a 64MB cap in development
    config.cache_store = :memory_store, { size: 64.megabytes, expires_in: default_ttl.seconds }
  else
    # Test: null store to avoid cache interference
    config.cache_store = :null_store
  end

  # Enable caching in development when toggled via `rails dev:cache`
  if Rails.env.development?
    config.action_controller.perform_caching = Rails.root.join('tmp', 'caching-dev.txt').exist?
  end

  # Warm cache on boot in production (non-blocking)
  config.after_initialize do
    if Rails.env.production?
      Thread.new do
        sleep 5 # let app finish booting
        CacheService.warm!
      rescue StandardError => e
        Rails.logger.error "[Caching] Cache warm on boot failed: #{e.message}"
      end
    end
  end
end
