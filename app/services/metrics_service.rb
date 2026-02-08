# frozen_string_literal: true

# In-process metrics collection with Prometheus-compatible output.
# Thread-safe via Mutex. No external dependencies.
#
# Usage:
#   MetricsService.increment(:commands_sent_total, labels: { type: 'shell' })
#   MetricsService.set_gauge(:active_devices, 5)
#   MetricsService.observe_histogram(:command_response_time, 0.342)
#   MetricsService.to_prometheus  # => Prometheus text format
class MetricsService
  class << self
    def instance
      @instance ||= new
    end

    delegate :increment, :set_gauge, :observe_histogram,
             :get_counter, :get_gauge, :get_histogram,
             :to_prometheus, :reset!, to: :instance
  end

  HISTOGRAM_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60].freeze

  def initialize
    @mutex = Mutex.new
    @counters = Hash.new(0)
    @gauges = {}
    @histograms = {}
    @boot_time = Time.current
  end

  # -- Counters --

  def increment(name, amount: 1, labels: {})
    key = metric_key(name, labels)
    @mutex.synchronize { @counters[key] += amount }
  end

  def get_counter(name, labels: {})
    @mutex.synchronize { @counters[metric_key(name, labels)] }
  end

  # -- Gauges --

  def set_gauge(name, value, labels: {})
    key = metric_key(name, labels)
    @mutex.synchronize { @gauges[key] = value }
  end

  def get_gauge(name, labels: {})
    @mutex.synchronize { @gauges[metric_key(name, labels)] }
  end

  # -- Histograms --

  def observe_histogram(name, value, labels: {})
    key = metric_key(name, labels)
    @mutex.synchronize do
      @histograms[key] ||= { buckets: Hash.new(0), sum: 0.0, count: 0 }
      h = @histograms[key]
      HISTOGRAM_BUCKETS.each { |b| h[:buckets][b] += 1 if value <= b }
      h[:sum] += value
      h[:count] += 1
    end
  end

  def get_histogram(name, labels: {})
    @mutex.synchronize { @histograms[metric_key(name, labels)]&.dup }
  end

  # -- Prometheus export --

  def to_prometheus
    lines = []
    @mutex.synchronize do
      # Counters
      grouped_counters = group_by_metric(@counters)
      grouped_counters.each do |metric, entries|
        lines << "# HELP #{metric} Counter metric"
        lines << "# TYPE #{metric} counter"
        entries.each { |key, val| lines << "#{key} #{val}" }
      end

      # Gauges
      grouped_gauges = group_by_metric(@gauges)
      grouped_gauges.each do |metric, entries|
        lines << "# HELP #{metric} Gauge metric"
        lines << "# TYPE #{metric} gauge"
        entries.each { |key, val| lines << "#{key} #{val}" }
      end

      # Histograms
      grouped_histograms = group_by_metric(@histograms)
      grouped_histograms.each do |metric, entries|
        lines << "# HELP #{metric} Histogram metric"
        lines << "# TYPE #{metric} histogram"
        entries.each do |key, data|
          base = key.sub(/\{.*\}/, '')
          label_part = key[/\{.*\}/] || ''
          HISTOGRAM_BUCKETS.each do |b|
            le_labels = label_part.empty? ? "{le=\"#{b}\"}" : label_part.sub('}', ",le=\"#{b}\"}")
            lines << "#{base}_bucket#{le_labels} #{data[:buckets][b]}"
          end
          inf_labels = label_part.empty? ? '{le="+Inf"}' : label_part.sub('}', ',le="+Inf"}')
          lines << "#{base}_bucket#{inf_labels} #{data[:count]}"
          lines << "#{base}_sum#{label_part} #{data[:sum]}"
          lines << "#{base}_count#{label_part} #{data[:count]}"
        end
      end

      # Process metrics
      lines.concat(process_metrics)
    end

    lines.join("\n") + "\n"
  end

  def reset!
    @mutex.synchronize do
      @counters.clear
      @gauges.clear
      @histograms.clear
    end
  end

  private

  def metric_key(name, labels)
    return name.to_s if labels.empty?

    label_str = labels.map { |k, v| "#{k}=\"#{v}\"" }.sort.join(',')
    "#{name}{#{label_str}}"
  end

  def group_by_metric(hash)
    groups = Hash.new { |h, k| h[k] = {} }
    hash.each do |key, val|
      metric_name = key.to_s.sub(/\{.*/, '')
      groups[metric_name][key] = val
    end
    groups
  end

  def process_metrics
    lines = []
    rss = process_memory_rss
    uptime = (Time.current - @boot_time).to_i

    lines << '# HELP process_resident_memory_bytes Resident memory size in bytes'
    lines << '# TYPE process_resident_memory_bytes gauge'
    lines << "process_resident_memory_bytes #{rss}"
    lines << '# HELP process_uptime_seconds Process uptime in seconds'
    lines << '# TYPE process_uptime_seconds gauge'
    lines << "process_uptime_seconds #{uptime}"
    lines
  end

  def process_memory_rss
    if Gem.win_platform?
      pid = Process.pid
      output = `tasklist /FI "PID eq #{pid}" /FO CSV /NH 2>NUL`.strip
      # "ruby.exe","1234","Console","1","52,480 K"
      match = output.match(/"([\d,]+)\s*K"/)
      match ? match[1].delete(',').to_i * 1024 : 0
    else
      `ps -o rss= -p #{Process.pid}`.strip.to_i * 1024
    end
  rescue StandardError
    0
  end
end
