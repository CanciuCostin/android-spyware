# frozen_string_literal: true

# Circuit Breaker pattern to prevent cascading failures.
# States: closed (normal), open (failing), half-open (testing recovery).
# Uses Redis for state persistence across processes.
class CircuitBreaker
  STATES = %w[closed open half_open].freeze

  DEFAULT_OPTIONS = {
    failure_threshold: 5,
    timeout: 30,           # seconds before transitioning from open -> half_open
    half_open_max_calls: 1 # max calls allowed in half_open before deciding
  }.freeze

  attr_reader :service_name

  def initialize(service_name, options = {})
    @service_name = service_name
    @options = DEFAULT_OPTIONS.merge(options)
  end

  # Execute a block with circuit breaker protection
  def call(&block)
    raise ArgumentError, "Block required" unless block_given?

    case state
    when 'open'
      if timeout_elapsed?
        try_half_open(&block)
      else
        raise CircuitOpenError.new(@service_name, time_until_retry)
      end
    when 'half_open'
      try_half_open(&block)
    else # closed
      execute(&block)
    end
  end

  def state
    RedisPool.with { |r| r.get(state_key) } || 'closed'
  rescue StandardError
    'closed'
  end

  def failure_count
    (RedisPool.with { |r| r.get(failure_count_key) } || 0).to_i
  rescue StandardError
    0
  end

  def reset!
    RedisPool.with do |redis|
      redis.del(state_key, failure_count_key, opened_at_key, half_open_calls_key)
    end
    Rails.logger.info "[CircuitBreaker] #{@service_name}: Reset to closed"
  rescue StandardError => e
    Rails.logger.error "[CircuitBreaker] #{@service_name}: Reset failed: #{e.message}"
  end

  def metrics
    {
      service: @service_name,
      state: state,
      failure_count: failure_count,
      failure_threshold: @options[:failure_threshold],
      timeout: @options[:timeout]
    }
  end

  # Class-level registry for all circuit breakers
  def self.for(service_name, options = {})
    @registry ||= {}
    @registry[service_name] ||= new(service_name, options)
  end

  def self.all_metrics
    return [] unless @registry
    @registry.values.map(&:metrics)
  end

  private

  def execute(&block)
    result = block.call
    record_success
    result
  rescue StandardError => e
    record_failure
    raise
  end

  def try_half_open(&block)
    transition_to('half_open') unless state == 'half_open'

    result = block.call
    record_success
    transition_to('closed')
    result
  rescue StandardError => e
    record_failure
    transition_to('open')
    raise
  end

  def record_success
    RedisPool.with do |redis|
      redis.del(failure_count_key)
    end
  rescue StandardError => e
    Rails.logger.error "[CircuitBreaker] #{@service_name}: Failed to record success: #{e.message}"
  end

  def record_failure
    RedisPool.with do |redis|
      count = redis.incr(failure_count_key)

      if count >= @options[:failure_threshold]
        transition_to('open')
        Rails.logger.warn "[CircuitBreaker] #{@service_name}: OPENED after #{count} failures"
      end
    end
  rescue StandardError => e
    Rails.logger.error "[CircuitBreaker] #{@service_name}: Failed to record failure: #{e.message}"
  end

  def transition_to(new_state)
    RedisPool.with do |redis|
      redis.set(state_key, new_state)

      if new_state == 'open'
        redis.set(opened_at_key, Time.current.to_f)
      elsif new_state == 'closed'
        redis.del(failure_count_key, opened_at_key, half_open_calls_key)
      end
    end

    Rails.logger.info "[CircuitBreaker] #{@service_name}: Transitioned to #{new_state}"
  rescue StandardError => e
    Rails.logger.error "[CircuitBreaker] #{@service_name}: Transition failed: #{e.message}"
  end

  def timeout_elapsed?
    opened_at = RedisPool.with { |r| r.get(opened_at_key) }
    return true unless opened_at
    (Time.current.to_f - opened_at.to_f) >= @options[:timeout]
  rescue StandardError
    true
  end

  def time_until_retry
    opened_at = RedisPool.with { |r| r.get(opened_at_key) }
    return 0 unless opened_at
    remaining = @options[:timeout] - (Time.current.to_f - opened_at.to_f)
    [remaining, 0].max.ceil
  rescue StandardError
    0
  end

  def state_key
    "circuit_breaker:#{@service_name}:state"
  end

  def failure_count_key
    "circuit_breaker:#{@service_name}:failures"
  end

  def opened_at_key
    "circuit_breaker:#{@service_name}:opened_at"
  end

  def half_open_calls_key
    "circuit_breaker:#{@service_name}:half_open_calls"
  end

  class CircuitOpenError < StandardError
    attr_reader :service_name, :retry_after

    def initialize(service_name, retry_after)
      @service_name = service_name
      @retry_after = retry_after
      super("Circuit breaker open for '#{service_name}'. Retry after #{retry_after}s.")
    end
  end
end
