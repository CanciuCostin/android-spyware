# frozen_string_literal: true

# Retry handler with exponential backoff, jitter, and dead letter queue.
# Wraps any operation with configurable retry logic.
class RetryHandler
  DEFAULT_OPTIONS = {
    max_retries: 3,
    base_delay: 1,           # seconds
    max_delay: 60,            # seconds
    jitter: true,
    retryable_errors: [StandardError],
    non_retryable_errors: [ArgumentError, NoMethodError],
    dead_letter_queue: true
  }.freeze

  attr_reader :attempts

  def initialize(operation_name, options = {})
    @operation_name = operation_name
    @options = DEFAULT_OPTIONS.merge(options)
    @attempts = 0
  end

  # Execute block with retry logic
  def call(&block)
    raise ArgumentError, "Block required" unless block_given?

    @attempts = 0

    begin
      @attempts += 1
      result = block.call
      result
    rescue *@options[:non_retryable_errors] => e
      Rails.logger.error "[RetryHandler] #{@operation_name}: Non-retryable error (#{e.class}): #{e.message}"
      send_to_dead_letter(e)
      raise
    rescue *@options[:retryable_errors] => e
      if @attempts <= @options[:max_retries]
        delay = calculate_delay
        Rails.logger.warn "[RetryHandler] #{@operation_name}: Attempt #{@attempts}/#{@options[:max_retries]} failed: #{e.message}. Retrying in #{delay.round(2)}s"
        sleep(delay)
        retry
      else
        Rails.logger.error "[RetryHandler] #{@operation_name}: All #{@options[:max_retries]} retries exhausted: #{e.message}"
        send_to_dead_letter(e)
        raise
      end
    end
  end

  # Convenience class method
  def self.with_retry(operation_name, options = {}, &block)
    new(operation_name, options).call(&block)
  end

  # Retrieve dead letter queue items
  def self.dead_letter_items(limit: 50)
    RedisPool.with do |redis|
      items = redis.lrange('retry:dead_letter_queue', 0, limit - 1)
      items.map { |item| JSON.parse(item) }
    end
  rescue StandardError => e
    Rails.logger.error "[RetryHandler] Failed to read dead letter queue: #{e.message}"
    []
  end

  # Clear dead letter queue
  def self.clear_dead_letter_queue!
    RedisPool.with { |redis| redis.del('retry:dead_letter_queue') }
  rescue StandardError => e
    Rails.logger.error "[RetryHandler] Failed to clear dead letter queue: #{e.message}"
  end

  # Retry a specific dead letter item by index
  def self.retry_dead_letter(index, &block)
    items = dead_letter_items
    return Result.failure("Invalid index") if index < 0 || index >= items.length

    item = items[index]
    Rails.logger.info "[RetryHandler] Retrying dead letter item: #{item['operation']}"

    begin
      result = block.call(item)
      # Remove from DLQ on success
      RedisPool.with do |redis|
        redis.lrem('retry:dead_letter_queue', 1, item.to_json)
      end
      Result.success(result)
    rescue StandardError => e
      Result.failure(e.message)
    end
  end

  private

  def calculate_delay
    # Exponential backoff: base * 2^(attempt-1)
    delay = @options[:base_delay] * (2**(@attempts - 1))
    delay = [delay, @options[:max_delay]].min

    if @options[:jitter]
      # Full jitter: random between 0 and calculated delay
      delay = rand * delay
    end

    delay
  end

  def send_to_dead_letter(error)
    return unless @options[:dead_letter_queue]

    item = {
      operation: @operation_name,
      error_class: error.class.name,
      error_message: error.message,
      attempts: @attempts,
      failed_at: Time.current.iso8601
    }

    RedisPool.with do |redis|
      redis.lpush('retry:dead_letter_queue', item.to_json)
      # Cap the DLQ at 1000 items
      redis.ltrim('retry:dead_letter_queue', 0, 999)
    end

    Rails.logger.info "[RetryHandler] #{@operation_name}: Sent to dead letter queue"
  rescue StandardError => e
    Rails.logger.error "[RetryHandler] Failed to write to dead letter queue: #{e.message}"
  end
end
