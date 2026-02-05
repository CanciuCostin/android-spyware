require 'rack/attack'

class Rack::Attack
  # Use memory store to mitigate distributed attacks
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttle API requests per IP
  # Using 'api/ip' key to avoid conflict with general 'req/ip'
  throttle('api/ip', limit: (ENV['RATE_LIMIT_PER_IP'].presence || 120).to_i, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api')
  end

  # Throttle API requests per device
  throttle('req/device', limit: (ENV['RATE_LIMIT_PER_DEVICE'].presence || 90).to_i, period: 1.minute) do |req|
    req.get_header('HTTP_X_DEVICE_ID') if req.path.start_with?('/api')
  end

  # Throttle all requests by IP (General)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts - Brute Force Protection
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/admin/login' && req.post?
      req.ip
    end
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |_env|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Rate limit exceeded' }.to_json]
    ]
  end

  # Block attacks from specific user agents (optional)
  # blocklist('block bad UA') do |req|
  #   req.user_agent == 'BadUA'
  # end
end

Rails.application.config.middleware.use Rack::Attack
