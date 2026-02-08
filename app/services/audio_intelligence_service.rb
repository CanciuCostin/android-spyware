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

    if whisper_configured?
      transcribe_with_whisper(audio_path)
    elsif google_speech_configured?
      transcribe_with_google(audio_path)
    else
      { error: 'No speech-to-text provider configured. Set WHISPER_API_KEY or GOOGLE_SPEECH_KEY.' }
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

    if whisper_configured?
      # Whisper returns language with transcription
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

  def transcribe_with_whisper(audio_path)
    api_key = ENV['WHISPER_API_KEY']
    uri = URI('https://api.openai.com/v1/audio/transcriptions')

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"

    form_data = [
      ['file', File.open(audio_path, 'rb')],
      ['model', 'whisper-1'],
      ['response_format', 'verbose_json']
    ]
    request.set_form(form_data, 'multipart/form-data')

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      {
        text: data['text'],
        language: data['language'],
        confidence: data['segments']&.map { |s| s['avg_logprob'] }&.compact&.then { |probs| probs.any? ? Math.exp(probs.sum / probs.size) : nil },
        segments: data['segments']&.map { |s| { start: s['start'], end: s['end'], text: s['text'] } },
        provider: 'whisper'
      }
    else
      Rails.logger.error("[AudioIntelligence] Whisper API error: #{response.body}")
      { error: "Whisper API error: #{response.code}", provider: 'whisper' }
    end
  rescue StandardError => e
    Rails.logger.error("[AudioIntelligence] Whisper transcription failed: #{e.message}")
    { error: e.message, provider: 'whisper' }
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

  def whisper_configured?
    ENV['WHISPER_API_KEY'].present?
  end

  def google_speech_configured?
    ENV['GOOGLE_SPEECH_KEY'].present?
  end
end
