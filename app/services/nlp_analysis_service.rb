# frozen_string_literal: true

class NlpAnalysisService < ApplicationService
  # Built-in patterns for entity extraction (no external API needed)
  PHONE_PATTERN = /(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}/
  EMAIL_PATTERN = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
  URL_PATTERN   = %r{https?://[^\s<>"{}|\\^`\[\]]+}i
  SSN_PATTERN   = /\b\d{3}-\d{2}-\d{4}\b/
  CC_PATTERN    = /\b(?:\d{4}[-\s]?){3}\d{4}\b/
  IP_PATTERN    = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/

  POSITIVE_WORDS = %w[good great awesome love happy excellent wonderful amazing best thanks thank nice beautiful perfect].freeze
  NEGATIVE_WORDS = %w[bad terrible awful hate angry horrible worst sad sorry ugly wrong fail failure sucks].freeze

  # ISO 639-1 trigram hints for common languages
  LANGUAGE_HINTS = {
    'en' => %w[the and for are but not you all can her was one our how],
    'es' => %w[que por los del las una con para más esta],
    'fr' => %w[les des une que pour dans est pas sur ont],
    'de' => %w[der die und den das ist ein nicht mit sich],
    'bg' => %w[на за от да не се със при или как],
    'ru' => %w[что это как так все они для при или],
    'pt' => %w[que para com por uma dos das não como mais],
    'it' => %w[che per con una del suo gli dei non questo]
  }.freeze

  def initialize(text, options = {})
    @text = text.to_s
    @options = options
    @api_key = ENV['GEMINI_API_KEY']
  end

  def call
    return Result.failure('Text is required') if @text.blank?

    Result.success(full_analysis)
  rescue StandardError => e
    Rails.logger.error("[NlpAnalysisService] #{e.message}")
    Result.failure(e.message)
  end

  # --- Full Analysis ---

  def full_analysis
    {
      entities: extract_entities,
      sentiment: analyze_sentiment,
      language: detect_language,
      pii: detect_pii,
      summary: {
        word_count: word_count,
        char_count: @text.length,
        sentence_count: sentence_count
      }
    }
  end

  # --- Entity Extraction ---

  def extract_entities
    if @api_key.present?
      ai_extract_entities
    else
      pattern_extract_entities
    end
  end

  def pattern_extract_entities
    {
      phone_numbers: @text.scan(PHONE_PATTERN).map(&:to_s).reject(&:blank?).uniq,
      emails: @text.scan(EMAIL_PATTERN).uniq,
      urls: @text.scan(URL_PATTERN).uniq,
      ip_addresses: @text.scan(IP_PATTERN).uniq,
      capitalized_words: extract_proper_nouns
    }
  end

  def extract_proper_nouns
    words = @text.scan(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b/)
    # Filter out sentence starters by removing first word of each sentence
    sentence_starts = @text.scan(/(?:^|[.!?]\s+)([A-Z][a-z]+)/).flatten
    (words - sentence_starts).uniq.first(20)
  end

  # --- Sentiment Analysis ---

  def analyze_sentiment
    if @api_key.present?
      ai_sentiment_analysis
    else
      lexicon_sentiment_analysis
    end
  end

  def lexicon_sentiment_analysis
    words = @text.downcase.split(/\W+/)
    positive = words.count { |w| POSITIVE_WORDS.include?(w) }
    negative = words.count { |w| NEGATIVE_WORDS.include?(w) }
    total = positive + negative

    if total == 0
      score = 0.0
      label = 'neutral'
    else
      score = ((positive - negative).to_f / total).round(3)
      label = if score > 0.2
                'positive'
              elsif score < -0.2
                'negative'
              else
                'neutral'
              end
    end

    {
      score: score,
      label: label,
      positive_count: positive,
      negative_count: negative,
      method: 'lexicon'
    }
  end

  # --- Language Detection ---

  def detect_language
    words = @text.downcase.split(/\W+/).select { |w| w.length > 1 }
    return { language: 'unknown', confidence: 0 } if words.size < 3

    scores = LANGUAGE_HINTS.map do |lang, hints|
      matches = words.count { |w| hints.include?(w) }
      [lang, matches]
    end.to_h

    best_lang, best_score = scores.max_by { |_, v| v }
    confidence = best_score > 0 ? (best_score.to_f / words.size * 100).clamp(0, 100).round(1) : 0

    {
      language: best_score > 0 ? best_lang : 'unknown',
      confidence: confidence,
      scores: scores.select { |_, v| v > 0 }
    }
  end

  # --- PII Detection & Redaction ---

  def detect_pii
    findings = []

    @text.scan(PHONE_PATTERN).each { |m| findings << { type: 'phone_number', value: m.to_s, risk: 'medium' } }
    @text.scan(EMAIL_PATTERN).each { |m| findings << { type: 'email', value: m, risk: 'medium' } }
    @text.scan(SSN_PATTERN).each  { |m| findings << { type: 'ssn', value: m, risk: 'critical' } }
    @text.scan(CC_PATTERN).each   { |m| findings << { type: 'credit_card', value: m, risk: 'critical' } }
    @text.scan(IP_PATTERN).each   { |m| findings << { type: 'ip_address', value: m, risk: 'low' } }

    {
      pii_found: findings.any?,
      count: findings.size,
      findings: findings.uniq { |f| f[:value] },
      redacted_text: redact_text
    }
  end

  def redact_text
    redacted = @text.dup
    redacted.gsub!(SSN_PATTERN, '[SSN REDACTED]')
    redacted.gsub!(CC_PATTERN, '[CC REDACTED]')
    redacted.gsub!(EMAIL_PATTERN, '[EMAIL REDACTED]')
    redacted.gsub!(PHONE_PATTERN) { |m| m.length > 5 ? '[PHONE REDACTED]' : m }
    redacted
  end

  # Analyze messages for a device
  def self.analyze_device_messages(device, options = {})
    limit = options[:limit] || 100
    messages = device.sms_messages.order(created_at: :desc).limit(limit)

    results = messages.map do |msg|
      analysis = new(msg.body).full_analysis
      {
        message_id: msg.id,
        address: msg.address,
        type: msg.message_type,
        date: msg.created_at.iso8601,
        analysis: analysis
      }
    end

    aggregate_sentiment = results.map { |r| r.dig(:analysis, :sentiment, :score) }.compact
    avg_sentiment = aggregate_sentiment.empty? ? 0 : (aggregate_sentiment.sum / aggregate_sentiment.size).round(3)

    all_pii = results.flat_map { |r| r.dig(:analysis, :pii, :findings) || [] }

    {
      messages_analyzed: results.size,
      average_sentiment: avg_sentiment,
      total_pii_found: all_pii.size,
      pii_by_type: all_pii.group_by { |p| p[:type] }.transform_values(&:size),
      details: results
    }
  rescue StandardError => e
    Rails.logger.error("[NlpAnalysisService] Device analysis error: #{e.message}")
    { error: e.message }
  end

  private

  def word_count
    @text.split(/\s+/).size
  end

  def sentence_count
    @text.scan(/[.!?]+/).size.clamp(1, Float::INFINITY)
  end

  # --- AI-powered methods (require GEMINI_API_KEY) ---

  def ai_extract_entities
    prompt = "Extract named entities (people, places, organizations, dates) from this text. Return JSON with keys: people, places, organizations, dates.\n\nText: #{@text.truncate(2000)}"
    result = call_gemini_simple(prompt)
    parsed = JSON.parse(result, symbolize_names: true) rescue nil
    parsed || pattern_extract_entities
  end

  def ai_sentiment_analysis
    prompt = "Analyze the sentiment of this text. Return JSON: {score: -1.0 to 1.0, label: positive/negative/neutral, explanation: string}\n\nText: #{@text.truncate(2000)}"
    result = call_gemini_simple(prompt)
    parsed = JSON.parse(result, symbolize_names: true) rescue nil
    if parsed && parsed[:score]
      parsed[:method] = 'ai'
      parsed
    else
      lexicon_sentiment_analysis
    end
  end

  def call_gemini_simple(prompt)
    model = ENV.fetch('GEMINI_MODEL', 'gemini-2.0-flash')
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{@api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 500 }
    }.to_json

    response = http.request(request)
    JSON.parse(response.body).dig('candidates', 0, 'content', 'parts', 0, 'text') || ''
  end
end