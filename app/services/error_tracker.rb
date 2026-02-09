# frozen_string_literal: true

# Captures, classifies, and tracks application errors.
# Detects error spikes and provides summary data for the observability dashboard.
#
# Usage:
#   ErrorTracker.capture("Something broke", error: exception, device_id: "abc")
#   ErrorTracker.summary          # => { total: 42, by_class: { ... }, recent: [...] }
#   ErrorTracker.spike_detected?  # => true/false
class ErrorTracker
  MAX_RECENT = 200
  SPIKE_WINDOW = 60       # seconds
  SPIKE_THRESHOLD = 20    # errors per window

  class << self
    def instance
      @instance ||= new
    end

    delegate :capture, :summary, :spike_detected?, :recent_errors,
             :error_rate, :reset!, to: :instance
  end

  def initialize
    @mutex = Mutex.new
    @errors = []
    @counts_by_class = Hash.new(0)
    @counts_by_category = Hash.new(0)
    @total = 0
    @window_timestamps = []
  end

  def capture(message, context = {})
    error = context[:error]
    entry = {
      id: SecureRandom.uuid,
      timestamp: Time.current.iso8601(3),
      message: message.to_s.truncate(500),
      error_class: error&.class&.name || 'Unknown',
      error_message: error&.message&.truncate(300),
      backtrace: error&.backtrace&.first(5),
      category: classify_error(error),
      device_id: context[:device_id],
      request_id: context[:request_id],
      controller: context[:controller],
      action: context[:action]
    }

    @mutex.synchronize do
      @errors.unshift(entry)
      @errors.pop if @errors.size > MAX_RECENT

      @counts_by_class[entry[:error_class]] += 1
      @counts_by_category[entry[:category]] += 1
      @total += 1

      @window_timestamps << Time.current
      prune_window!
    end

    # Update metrics counters
    MetricsService.increment(:errors_total, labels: { category: entry[:category] }) if defined?(MetricsService)

    entry
  end

  def summary
    @mutex.synchronize do
      {
        total: @total,
        by_class: @counts_by_class.sort_by { |_, v| -v }.first(10).to_h,
        by_category: @counts_by_category.dup,
        recent: @errors.first(20),
        error_rate_per_minute: current_rate,
        spike: spike_active?
      }
    end
  end

  def spike_detected?
    @mutex.synchronize { spike_active? }
  end

  def recent_errors(limit = 20)
    @mutex.synchronize { @errors.first(limit) }
  end

  def error_rate
    @mutex.synchronize { current_rate }
  end

  def reset!
    @mutex.synchronize do
      @errors.clear
      @counts_by_class.clear
      @counts_by_category.clear
      @total = 0
      @window_timestamps.clear
    end
  end

  private

  CATEGORIES = {
    'ActiveRecord' => :database,
    'Redis' => :redis,
    'ActionCable' => :websocket,
    'Net::' => :network,
    'Timeout' => :timeout,
    'AdbCommandService' => :adb,
    'MsfRpcService' => :metasploit,
    'Errno::' => :system
  }.freeze

  def classify_error(error)
    return :unknown unless error

    class_name = error.class.name.to_s
    CATEGORIES.each do |prefix, category|
      return category if class_name.include?(prefix)
    end
    :application
  end

  def prune_window!
    cutoff = Time.current - SPIKE_WINDOW
    @window_timestamps.reject! { |t| t < cutoff }
  end

  def current_rate
    prune_window!
    return 0.0 if @window_timestamps.empty?

    (@window_timestamps.size.to_f / SPIKE_WINDOW * 60).round(2)
  end

  def spike_active?
    prune_window!
    @window_timestamps.size >= SPIKE_THRESHOLD
  end
end
