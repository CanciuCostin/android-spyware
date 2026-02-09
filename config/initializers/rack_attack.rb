require 'rack/attack'

class Rack::Attack
  Rack::Attack.cache.store = begin
    ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
  rescue => e
    Rails.logger.warn("[Rack::Attack] Redis unavailable (#{e.message}), falling back to MemoryStore")
    ActiveSupport::Cache::MemoryStore.new
  end

  ### Safelists ###

  # Allow internal/loopback IPs without throttling
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  safelist('allow-internal') do |req|
    ip = req.ip.to_s
    ip.start_with?('10.') || ip.start_with?('192.168.') ||
      (ip.start_with?('172.') && ip.split('.')[1].to_i.between?(16, 31))
  end

  # Allow device API endpoints without throttling
  safelist('allow-device-api') do |req|
    req.path.start_with?('/api/') || req.path.start_with?('/cable')
  end

  ### Blocklists ###

  # Dynamic blocklist via cache (managed by RateLimitService)
  blocklist('block-banned-ips') do |req|
    Rack::Attack.cache.read("blocked:#{req.ip}")
  end

  ### Throttles ###

  # Auth endpoints: 5 req/min per IP (brute force protection)
  throttle('auth/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path =~ %r{^/admin/login} && req.post?
  end

  # File uploads: 10 req/min per device
  throttle('uploads/device', limit: 10, period: 1.minute) do |req|
    if req.path =~ %r{^/api/(photos|audio|file_browser|sms|contacts|calls)} && req.post?
      req.get_header('HTTP_X_DEVICE_ID')
    end
  end

  # Commands: 30 req/min per device
  throttle('commands/device', limit: 30, period: 1.minute) do |req|
    if req.path =~ %r{^/api/commands}
      req.get_header('HTTP_X_DEVICE_ID')
    end
  end

  # API general: 100 req/min per IP
  throttle('api/ip', limit: (ENV['RATE_LIMIT_PER_IP'].presence || 100).to_i, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api')
  end

  # WebSocket connections: 5/min per IP
  throttle('websocket/ip', limit: 5, period: 1.minute) do |req|
    req.ip if req.path =~ %r{^/cable} || req.path =~ %r{^/webrtc}
  end

  # Admin panel: 20 req/min per IP
  throttle('admin/ip', limit: 20, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/admin') && !req.path.include?('/login')
  end

  # Device-level general throttle
  throttle('req/device', limit: (ENV['RATE_LIMIT_PER_DEVICE'].presence || 90).to_i, period: 1.minute) do |req|
    req.get_header('HTTP_X_DEVICE_ID') if req.path.start_with?('/api')
  end

  # Global throttle per IP
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  ### Exponential Backoff ###

  # Track repeated violations for exponential backoff
  # After 3 throttle hits within 10 minutes, block for escalating durations
  (1..5).each do |level|
    blocklist("exponential-backoff-L#{level}") do |req|
      key = "rack::attack:violations:#{req.ip}"
      violations = Rack::Attack.cache.read(key).to_i
      violations >= (3 * level)
    end
  end

  ### Custom Throttle Response ###

  self.throttled_responder = lambda do |req|
    match_data = req.env['rack.attack.match_data'] || {}
    now = match_data[:epoch_time] || Time.now.to_i
    period = match_data[:period] || 60
    retry_after = (period - (now % period)).to_i

    # Track violations for exponential backoff
    violations_key = "rack::attack:violations:#{req.ip}"
    current = Rack::Attack.cache.read(violations_key).to_i
    Rack::Attack.cache.write(violations_key, current + 1, expires_in: 10.minutes)

    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s,
      'X-RateLimit-Limit' => (match_data[:limit] || 0).to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + retry_after).to_s
    }

    body = {
      error: 'Rate limit exceeded',
      retry_after: retry_after,
      throttle: req.env['rack.attack.matched']
    }.to_json

    [429, headers, [body]]
  end

  ### Instrumentation ###

  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn(
      "[Rack::Attack] Throttled #{req.env['rack.attack.matched']} " \
      "from #{req.ip} on #{req.path}"
    )
  end

  ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] Blocked #{req.ip} on #{req.path}")
  end
end

Rails.application.config.middleware.use Rack::Attack
