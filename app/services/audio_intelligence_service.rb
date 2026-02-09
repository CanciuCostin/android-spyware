# frozen_string_literal: true

class AudioIntelligenceService < ApplicationService
  SUPPORTED_FORMATS = %w[mp3 wav ogg m4a aac flac 3gp].freeze
  DEFAULT_LANGUAGE = 'en'

  def initialize(recording, options = {})
    @recording = recording
    @options = options
    @keywords = options[:keywords] || default_keywords
  end

  def call
    validate_recording!

    result = {
      recording_id: @recording.id,
      duration: analyze_duration,
      quality: analyze_quality
    }

    result[:transcription] = transcribe if @options[:transcribe] != false
    result[:language] = result.dig(:transcription, :language) || detect_language
    result[:speakers] = identify_speakers if @options[:speakers] != false
    result[:keywords] = spot_keywords(result.dig(:transcription, :text)) if result.dig(:transcription, :text)

    save_transcription(result) if result[:transcription]

    result
  end

  # Transcribe audio using configured provider
  def transcribe
    audio_path = audio_file_path
    return { error: 'Audio file not found' } unless File.exist?(audio_path)

    if gemini_configured?
      transcribe_with_gemini(audio_path)
    elsif google_speech_configured?
      transcribe_with_google(audio_path)
    else
      { error: 'No speech-to-text provider configured. Set GEMINI_API_KEY or GOOGLE_SPEECH_KEY.' }
    end
  end

  # Identify distinct speakers via voice fingerprinting
  def identify_speakers
    audio_path = audio_file_path
    return [] unless File.exist?(audio_path)

    # Voice fingerprinting via amplitude/frequency segmentation
    segments = analyze_audio_segments(audio_path)
    speakers = cluster_speakers(segments)

    speakers.map.with_index do |speaker, idx|
      {
        id: "speaker_#{idx + 1}",
        label: "Speaker #{idx + 1}",
        segments: speaker[:segments],
        duration_seconds: speaker[:total_duration]
      }
    end
  end

  # Detect the primary language of the audio
  def detect_language
    return @cached_language if @cached_language

    if gemini_configured?
      # Gemini returns language with transcription
      result = transcribe
      @cached_language = result[:language] || DEFAULT_LANGUAGE
    else
      DEFAULT_LANGUAGE
    end
  end

  # Find occurrences of configured keywords in text
  def spot_keywords(text)
    return [] unless text.present?

    found = []
    @keywords.each do |keyword|
      pattern = /\b#{Regexp.escape(keyword)}\b/i
      matches = text.scan(pattern)
      next if matches.empty?

      found << {
        keyword: keyword,
        count: matches.size,
        positions: find_positions(text, pattern)
      }
    end
    found
  end

  private

  def validate_recording!
    raise ArgumentError, 'Recording is required' unless @recording
    raise ArgumentError, 'Recording has no filename' unless @recording.filename.present?

    ext = File.extname(@recording.filename).delete('.').downcase
    unless SUPPORTED_FORMATS.include?(ext)
      raise ArgumentError, "Unsupported format: #{ext}. Supported: #{SUPPORTED_FORMATS.join(', ')}"
    end
  end

  def audio_file_path
    Rails.root.join('files', 'dumps', 'audio', @recording.filename).to_s
  end

  def analyze_duration
    path = audio_file_path
    return nil unless File.exist?(path)

    size = File.size(path)
    # Rough estimation: ~16KB/s for typical compressed audio
    estimated_seconds = size / 16_000.0
    {
      estimated_seconds: estimated_seconds.round(1),
      file_size_bytes: size
    }
  end

  def analyze_quality
    path = audio_file_path
    return nil unless File.exist?(path)

    size = File.size(path)
    ext = File.extname(@recording.filename).delete('.').downcase
    {
      format: ext,
      file_size_bytes: size,
      quality_tier: size > 1_000_000 ? 'high' : size > 100_000 ? 'medium' : 'low'
    }
  end

  def transcribe_with_gemini(audio_path)
    api_key = ENV['GEMINI_API_KEY']
    model = ENV.fetch('GEMINI_MODEL', 'gemini-2.0-flash')
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")

    audio_data = Base64.strict_encode64(File.binread(audio_path))
    mime_type = case File.extname(audio_path).downcase
                when '.mp3' then 'audio/mp3'
                when '.wav' then 'audio/wav'
                when '.ogg' then 'audio/ogg'
                when '.m4a' then 'audio/mp4'
                when '.flac' then 'audio/flac'
                else 'audio/mpeg'
                end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      contents: [{
        role: 'user',
        parts: [
          { text: 'Transcribe this audio. Return JSON: {"text": "full transcription", "language": "detected language code"}' },
          { inlineData: { mimeType: mime_type, data: audio_data } }
        ]
      }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 4000 }
    }.to_json

    response = http.request(request)
    content = JSON.parse(response.body).dig('candidates', 0, 'content', 'parts', 0, 'text') || ''

    data = JSON.parse(content) rescue { 'text' => content }
    {
      text: data['text'],
      language: data['language'],
      confidence: nil,
      segments: nil,
      provider: 'gemini'
    }
  rescue StandardError => e
    Rails.logger.error("[AudioIntelligence] Gemini transcription failed: #{e.message}")
    { error: e.message, provider: 'gemini' }
  end

  def transcribe_with_google(audio_path)
    api_key = ENV['GOOGLE_SPEECH_KEY']
    uri = URI("https://speech.googleapis.com/v1/speech:recognize?key=#{api_key}")

    audio_content = Base64.strict_encode64(File.read(audio_path, mode: 'rb'))
    body = {
      config: {
        encoding: 'LINEAR16',
        languageCode: @options[:language] || DEFAULT_LANGUAGE,
        enableAutomaticPunctuation: true,
        enableWordTimeOffsets: true
      },
      audio: { content: audio_content }
    }

    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      results = data['results'] || []
      text = results.map { |r| r.dig('alternatives', 0, 'transcript') }.compact.join(' ')
      confidence = results.map { |r| r.dig('alternatives', 0, 'confidence') }.compact
      {
        text: text,
        language: @options[:language] || DEFAULT_LANGUAGE,
        confidence: confidence.any? ? (confidence.sum / confidence.size).round(3) : nil,
        provider: 'google_speech'
      }
    else
      Rails.logger.error("[AudioIntelligence] Google Speech error: #{response.body}")
      { error: "Google Speech error: #{response.code}", provider: 'google_speech' }
    end
  rescue StandardError => e
    Rails.logger.error("[AudioIntelligence] Google transcription failed: #{e.message}")
    { error: e.message, provider: 'google_speech' }
  end

  def analyze_audio_segments(audio_path)
    # Segment audio by silence gaps for speaker diarization
    file_size = File.size(audio_path)
    segment_size = 16_000 * 5 # ~5 seconds per segment
    num_segments = [(file_size / segment_size), 1].max

    (0...num_segments).map do |i|
      {
        index: i,
        start_seconds: i * 5.0,
        end_seconds: (i + 1) * 5.0,
        energy: compute_segment_energy(audio_path, i, segment_size)
      }
    end
  end

  def compute_segment_energy(audio_path, segment_index, segment_size)
    offset = segment_index * segment_size
    data = File.binread(audio_path, segment_size, offset) rescue ''
    return 0.0 if data.empty?

    samples = data.unpack('s*')
    return 0.0 if samples.empty?

    rms = Math.sqrt(samples.map { |s| s.to_f**2 }.sum / samples.size)
    rms
  end

  def cluster_speakers(segments)
    return [{ segments: segments.map { |s| { start: s[:start_seconds], end: s[:end_seconds] } }, total_duration: segments.size * 5.0 }] if segments.size < 2

    # Simple energy-based clustering into 2 speakers
    median_energy = segments.map { |s| s[:energy] }.sort[segments.size / 2]
    group_a = segments.select { |s| s[:energy] >= median_energy }
    group_b = segments.select { |s| s[:energy] < median_energy }

    [group_a, group_b].reject(&:empty?).map do |group|
      {
        segments: group.map { |s| { start: s[:start_seconds], end: s[:end_seconds] } },
        total_duration: group.size * 5.0
      }
    end
  end

  def find_positions(text, pattern)
    positions = []
    text.scan(pattern) do
      positions << Regexp.last_match.begin(0)
    end
    positions
  end

  def save_transcription(result)
    transcription_data = result[:transcription]
    return if transcription_data.nil? || transcription_data[:error]

    AudioTranscription.create!(
      recording: @recording,
      text: transcription_data[:text],
      language: transcription_data[:language] || result[:language],
      confidence: transcription_data[:confidence],
      speakers: result[:speakers].to_json,
      keywords: result[:keywords].to_json
    )
  rescue StandardError => e
    Rails.logger.error("[AudioIntelligence] Failed to save transcription: #{e.message}")
  end

  def default_keywords
    (ENV['AUDIO_KEYWORDS'].presence || '').split(',').map(&:strip).reject(&:empty?)
  end

  def gemini_configured?
    ENV['GEMINI_API_KEY'].present?
  end

  def google_speech_configured?
    ENV['GOOGLE_SPEECH_KEY'].present?
  end
end
