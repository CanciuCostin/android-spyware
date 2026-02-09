# frozen_string_literal: true

class ImageRecognitionService < ApplicationService
  SUPPORTED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/bmp image/webp image/tiff].freeze

  def initialize(image_path_or_data, options = {})
    @image_path = image_path_or_data
    @options = options
    @google_api_key = ENV['GOOGLE_VISION_API_KEY']
    @openai_api_key = ENV['OPENAI_API_KEY']
  end

  def call
    return Result.failure('Image path or data is required') if @image_path.blank?

    Result.success(
      ocr: extract_text,
      faces: detect_faces,
      objects: detect_objects,
      metadata: extract_metadata
    )
  rescue StandardError => e
    Rails.logger.error("[ImageRecognitionService] #{e.message}")
    Result.failure(e.message)
  end

  # --- OCR (Text Extraction) ---

  def extract_text
    if @google_api_key.present?
      google_vision_ocr
    elsif @openai_api_key.present?
      openai_vision_ocr
    else
      stub_ocr
    end
  rescue StandardError => e
    { text: nil, error: e.message, method: 'error' }
  end

  # --- Face Detection ---

  def detect_faces
    if @google_api_key.present?
      google_vision_faces
    else
      stub_face_detection
    end
  rescue StandardError => e
    { faces: [], error: e.message }
  end

  # --- Object Detection ---

  def detect_objects
    if @google_api_key.present?
      google_vision_objects
    elsif @openai_api_key.present?
      openai_describe_image
    else
      stub_object_detection
    end
  rescue StandardError => e
    { objects: [], error: e.message }
  end

  # --- EXIF Metadata Extraction ---

  def extract_metadata
    return { error: 'File path required for metadata extraction' } unless File.exist?(@image_path.to_s)

    stat = File.stat(@image_path)
    exif_data = extract_exif_data

    {
      filename: File.basename(@image_path),
      file_size: stat.size,
      file_size_human: human_file_size(stat.size),
      mime_type: detect_mime_type,
      created_at: stat.ctime.iso8601,
      modified_at: stat.mtime.iso8601,
      exif: exif_data
    }
  rescue Errno::ENOENT
    { error: 'File not found', path: @image_path.to_s }
  rescue StandardError => e
    { error: e.message }
  end

  # Batch analyze images for a device
  def self.analyze_device_images(device, options = {})
    limit = options[:limit] || 20
    pictures = device.pictures.order(created_at: :desc).limit(limit)

    results = pictures.filter_map do |pic|
      path = pic.try(:file_path) || pic.try(:image_path)
      next unless path

      service = new(path)
      {
        picture_id: pic.id,
        created_at: pic.created_at.iso8601,
        analysis: service.call.success? ? service.call.value : { error: service.call.error }
      }
    end

    { images_analyzed: results.size, results: results }
  rescue StandardError => e
    { error: e.message }
  end

  private

  # --- Google Vision API implementations ---

  def google_vision_ocr
    response = call_google_vision('TEXT_DETECTION')
    annotations = response.dig('responses', 0, 'textAnnotations') || []

    {
      text: annotations.first&.dig('description') || '',
      blocks: annotations[1..].to_a.map { |a| { text: a['description'], bounds: a['boundingPoly'] } },
      confidence: response.dig('responses', 0, 'fullTextAnnotation', 'pages', 0, 'confidence'),
      method: 'google_vision'
    }
  end

  def google_vision_faces
    response = call_google_vision('FACE_DETECTION')
    annotations = response.dig('responses', 0, 'faceAnnotations') || []

    {
      count: annotations.size,
      faces: annotations.map do |face|
        {
          confidence: face['detectionConfidence'],
          joy: face['joyLikelihood'],
          sorrow: face['sorrowLikelihood'],
          anger: face['angerLikelihood'],
          surprise: face['surpriseLikelihood'],
          bounds: face['boundingPoly']
        }
      end,
      method: 'google_vision'
    }
  end

  def google_vision_objects
    response = call_google_vision('OBJECT_LOCALIZATION')
    annotations = response.dig('responses', 0, 'localizedObjectAnnotations') || []

    {
      count: annotations.size,
      objects: annotations.map do |obj|
        {
          name: obj['name'],
          confidence: obj['score'],
          bounds: obj['boundingPoly']
        }
      end,
      method: 'google_vision'
    }
  end

  def call_google_vision(feature_type)
    CircuitBreaker.for('google_vision').call do
      image_content = if File.exist?(@image_path.to_s)
                        Base64.strict_encode64(File.binread(@image_path))
                      else
                        @image_path.to_s
                      end

      uri = URI("https://vision.googleapis.com/v1/images:annotate?key=#{@google_api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        requests: [{
          image: { content: image_content },
          features: [{ type: feature_type, maxResults: 20 }]
        }]
      }.to_json

      response = http.request(request)
      JSON.parse(response.body)
    end
  rescue CircuitBreaker::CircuitOpenError => e
    { 'responses' => [{ 'error' => { 'message' => e.message } }] }
  end

  # --- OpenAI Vision implementations ---

  def openai_vision_ocr
    prompt = 'Extract all text visible in this image. Return only the extracted text, nothing else.'
    result = call_openai_vision(prompt)
    { text: result, method: 'openai_vision' }
  end

  def openai_describe_image
    prompt = 'List all objects you can identify in this image. Return JSON array: [{"name": "object", "confidence": 0.0-1.0}]'
    result = call_openai_vision(prompt)
    parsed = JSON.parse(result) rescue nil

    if parsed.is_a?(Array)
      { count: parsed.size, objects: parsed, method: 'openai_vision' }
    else
      { description: result, method: 'openai_vision' }
    end
  end

  def call_openai_vision(prompt)
    CircuitBreaker.for('openai_vision').call do
      image_url = if File.exist?(@image_path.to_s)
                    "data:#{detect_mime_type};base64,#{Base64.strict_encode64(File.binread(@image_path))}"
                  else
                    @image_path.to_s
                  end

      uri = URI('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@openai_api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: ENV.fetch('OPENAI_VISION_MODEL', 'gpt-4o-mini'),
        messages: [{
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: image_url } }
          ]
        }],
        max_tokens: 1000
      }.to_json

      response = http.request(request)
      JSON.parse(response.body).dig('choices', 0, 'message', 'content') || ''
    end
  rescue CircuitBreaker::CircuitOpenError => e
    "Service Temporarily Unavailable: #{e.message}"
  end

  # --- Stub implementations (no API configured) ---

  def stub_ocr
    {
      text: nil,
      method: 'stub',
      note: 'Configure GOOGLE_VISION_API_KEY or OPENAI_API_KEY for OCR. EXIF metadata extraction works without API keys.'
    }
  end

  def stub_face_detection
    {
      count: 0,
      faces: [],
      method: 'stub',
      note: 'Configure GOOGLE_VISION_API_KEY for face detection.'
    }
  end

  def stub_object_detection
    {
      count: 0,
      objects: [],
      method: 'stub',
      note: 'Configure GOOGLE_VISION_API_KEY or OPENAI_API_KEY for object detection.'
    }
  end

  # --- EXIF extraction (works without external APIs) ---

  def extract_exif_data
    return {} unless File.exist?(@image_path.to_s)

    # Read raw EXIF from JPEG files
    data = File.binread(@image_path, 65536)
    exif = {}

    if data[0..1] == "\xFF\xD8" # JPEG marker
      exif[:format] = 'JPEG'
      exif[:dimensions] = extract_jpeg_dimensions(data)

      # Look for EXIF APP1 marker
      if (app1_pos = data.index("\xFF\xE1"))
        exif[:has_exif] = true
        exif[:gps] = extract_gps_hint(data[app1_pos..]) rescue nil
      end
    elsif data[0..3] == "\x89PNG"
      exif[:format] = 'PNG'
      exif[:dimensions] = extract_png_dimensions(data)
    end

    exif
  rescue StandardError
    {}
  end

  def extract_jpeg_dimensions(data)
    # Search for SOF0 marker (0xFFC0)
    pos = 2
    while pos < data.size - 8
      if data[pos].ord == 0xFF
        marker = data[pos + 1].ord
        if [0xC0, 0xC2].include?(marker)
          height = data[pos + 5..pos + 6].unpack1('n')
          width = data[pos + 7..pos + 8].unpack1('n')
          return { width: width, height: height }
        end
        length = data[pos + 2..pos + 3].unpack1('n')
        pos += 2 + length
      else
        pos += 1
      end
    end
    nil
  rescue StandardError
    nil
  end

  def extract_png_dimensions(data)
    return nil if data.size < 24
    width = data[16..19].unpack1('N')
    height = data[20..23].unpack1('N')
    { width: width, height: height }
  rescue StandardError
    nil
  end

  def extract_gps_hint(data)
    # Simplified GPS detection — checks for GPS IFD presence
    has_gps = data.include?('GPS')
    { gps_data_present: has_gps }
  end

  def detect_mime_type
    return 'application/octet-stream' unless File.exist?(@image_path.to_s)

    header = File.binread(@image_path, 8)
    case
    when header[0..1] == "\xFF\xD8"         then 'image/jpeg'
    when header[0..3] == "\x89PNG"          then 'image/png'
    when header[0..3] == 'GIF8'            then 'image/gif'
    when header[0..1] == 'BM'             then 'image/bmp'
    when header[0..3] == 'RIFF'           then 'image/webp'
    else 'application/octet-stream'
    end
  rescue StandardError
    'application/octet-stream'
  end

  def human_file_size(bytes)
    units = %w[B KB MB GB]
    unit = 0
    size = bytes.to_f
    while size >= 1024 && unit < units.size - 1
      size /= 1024
      unit += 1
    end
    "#{size.round(1)} #{units[unit]}"
  end
end
