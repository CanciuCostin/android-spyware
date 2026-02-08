# frozen_string_literal: true

# Service for managing Rack::Attack rate limits programmatically.
# Provides methods to check status, block/unblock IPs, and gather statistics.
class RateLimitService < ApplicationService
  THROTTLE_RULES = {
    'auth/ip'          => { limit: 5,   period: 60,  description: 'Auth endpoints per IP' },
    'uploads/device'   => { limit: 10,  period: 60,  description: 'File uploads per device' },
    'commands/device'  => { limit: 30,  period: 60,  description: 'Commands per device' },
    'api/ip'           => { limit: 100, period: 60,  description: 'API general per IP' },
    'websocket/ip'     => { limit: 5,   period: 60,  description: 'WebSocket connections per IP' },
    'admin/ip'         => { limit: 20,  period: 60,  description: 'Admin panel per IP' },
    'req/device'       => { limit: 90,  period: 60,  description: 'All requests per device' },
    'req/ip'           => { limit: 300, period: 300, description: 'Global per IP' }
  }.freeze

  BLOCK_DURATION = 1.hour

  class << self
    # Check if an identifier is currently rate limited for a given throttle rule
    def rate_limit_status(throttle_name, identifier)
      rule = THROTTLE_RULES[throttle_name]
      return { error: "Unknown throttle: #{throttle_name}" } unless rule

      cache = Rack::Attack.cache
      key = "#{cache.prefix}:#{throttle_name}:#{identifier}"
      count = cache.store.read(key).to_i

      {
        throttle: throttle_name,
        identifier: identifier,
        description: rule[:description],
        current_count: count,
        limit: rule[:limit],
        period: rule[:period],
        remaining: [rule[:limit] - count, 0].max,
        blocked: blocked?(identifier)
      }
    end

    # Manually block an IP address
    def block_ip(ip, duration: BLOCK_DURATION)
      return { error: 'Invalid IP address' } if ip.blank?

      Rack::Attack.cache.write("blocked:#{ip}", true, expires_in: duration)
      Rails.logger.warn("[RateLimitService] Blocked IP #{ip} for #{duration} seconds")
      { success: true, ip: ip, blocked_until: Time.current + duration }
    end

    # Unblock a previously blocked IP
    def unblock_ip(ip)
      return { error: 'Invalid IP address' } if ip.blank?

      Rack::Attack.cache.store.delete("#{Rack::Attack.cache.prefix}:blocked:#{ip}")
      reset_violations(ip)
      Rails.logger.info("[RateLimitService] Unblocked IP #{ip}")
      { success: true, ip: ip }
    end

    # Check if an IP is blocked
    def blocked?(ip)
      !!Rack::Attack.cache.read("blocked:#{ip}")
    end

    # Reset rate limit counters for an identifier across all throttles
    def reset(identifier)
      cache = Rack::Attack.cache
      THROTTLE_RULES.each_key do |name|
        key = "#{cache.prefix}:#{name}:#{identifier}"
        cache.store.delete(key)
      end
      reset_violations(identifier)
      { success: true, identifier: identifier, reset_throttles: THROTTLE_RULES.keys }
    end

    # Get statistics for all throttle rules
    def statistics
      THROTTLE_RULES.map do |name, rule|
        {
          name: name,
          description: rule[:description],
          limit: rule[:limit],
          period: rule[:period]
        }
      end
    end

    # Get violation count for an IP
    def violation_count(ip)
      Rack::Attack.cache.read("rack::attack:violations:#{ip}").to_i
    end

    private

    def reset_violations(ip)
      key = "#{Rack::Attack.cache.prefix}:rack::attack:violations:#{ip}"
      Rack::Attack.cache.store.delete(key)
    end
  end

  def initialize(identifier = nil)
    @identifier = identifier
  end

  def call
    return Result.failure('Identifier required') if @identifier.blank?

    statuses = THROTTLE_RULES.keys.map do |name|
      self.class.rate_limit_status(name, @identifier)
    end

    Result.success(statuses)
  end
end
