class Rack::Attack
  # Use memory store to mitigate distributed attacks
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts (5 requests per 20 seconds) - Brute Force Protection
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/admin/login' && req.post?
      req.ip
    end
  end

  # Block attacks from specific user agents (optional)
  # blocklist('block bad UA') do |req|
  #   req.user_agent == 'BadUA'
  # end
end
