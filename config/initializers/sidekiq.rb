# frozen_string_literal: true

# Sidekiq configuration for background job processing.
# Uses the shared Redis connection from RedisPool where possible.

require 'sidekiq'

SIDEKIQ_REDIS_URL = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
SIDEKIQ_NAMESPACE = "eaglespy:#{Rails.env}:sidekiq"

Sidekiq.configure_server do |config|
  config.redis = {
    url: SIDEKIQ_REDIS_URL,
    namespace: SIDEKIQ_NAMESPACE,
    network_timeout: 5,
    pool_timeout: 5
  }

  # Server middleware for structured logging
  config.logger.level = Rails.logger.level

  # Scheduled jobs (cron-like via sidekiq-scheduler or manual enqueue)
  config.on(:startup) do
    Rails.logger.info "[Sidekiq] Server started — queues: #{Sidekiq.options[:queues]}"
  end

  config.on(:shutdown) do
    Rails.logger.info "[Sidekiq] Server shutting down"
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: SIDEKIQ_REDIS_URL,
    namespace: SIDEKIQ_NAMESPACE,
    network_timeout: 5,
    pool_timeout: 5,
    size: ENV.fetch('SIDEKIQ_CLIENT_POOL_SIZE', 5).to_i
  }
end

# Tell ActiveJob to use Sidekiq as the queue adapter (production/staging).
# In test/dev the default :async / :test adapter is usually fine.
if Rails.env.production? || Rails.env.staging?
  Rails.application.config.active_job.queue_adapter = :sidekiq
end
