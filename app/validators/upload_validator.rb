# frozen_string_literal: true

class UploadValidator
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  MAX_CHUNK_SIZE = 10.megabytes
  MAX_TOTAL_CHUNKS = 10_000
  MAX_FILENAME_LENGTH = 255

  ALLOWED_CONTENT_TYPES = %w[
    application/octet-stream
    image/jpeg image/png image/gif image/webp
    audio/mpeg audio/wav audio/ogg audio/3gpp
    video/mp4 video/3gpp
    application/json text/plain text/csv
    application/vnd.android.package-archive
  ].freeze

  DANGEROUS_EXTENSIONS = %w[
    .exe .bat .cmd .com .scr .pif .vbs .vbe .js .jse
    .wsf .wsh .msi .ps1 .psm1 .reg .inf .cpl .hta
    .rb .sh .py .pl .php .cgi .jsp .asp .aspx
  ].freeze

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(params)
    new.validate(params)
  end

  def self.validate_upload_id(upload_id)
    new.validate_upload_id(upload_id)
  end

  def validate(params)
    errors = []

    errors << validate_upload_id(params[:upload_id]).error unless validate_upload_id(params[:upload_id]).valid?

    if params[:filename]
      fname_result = validate_filename(params[:filename])
      errors << fname_result.error unless fname_result.valid?
    else
      errors << "Filename is required"
    end

    if params[:total_chunks]
      tc = params[:total_chunks].to_i
      errors << "Total chunks must be positive" if tc <= 0
      errors << "Too many chunks (max #{MAX_TOTAL_CHUNKS})" if tc > MAX_TOTAL_CHUNKS
    end

    if params[:chunk_index] && params[:total_chunks]
      ci = params[:chunk_index].to_i
      tc = params[:total_chunks].to_i
      errors << "Chunk index out of range" if ci.negative? || ci >= tc
    end

    if params[:file]
      file = params[:file]
      errors << "Chunk too large (max #{MAX_CHUNK_SIZE} bytes)" if file.respond_to?(:size) && file.size > MAX_CHUNK_SIZE
    end

    if params[:content_type] && !ALLOWED_CONTENT_TYPES.include?(params[:content_type])
      errors << "Content type '#{params[:content_type]}' not allowed"
    end

    errors.compact!
    return failure(errors.join('; ')) if errors.any?

    success(params)
  end

  def validate_upload_id(upload_id)
    return failure("Upload ID is required") if upload_id.nil? || upload_id.to_s.strip.empty?
    return failure("Invalid upload ID format") unless upload_id.to_s.match?(UUID_PATTERN)

    success(upload_id.to_s)
  end

  private

  def validate_filename(filename)
    name = filename.to_s.strip
    return failure("Filename is empty") if name.empty?
    return failure("Filename too long") if name.length > MAX_FILENAME_LENGTH
    return failure("Filename contains path separators") if name.include?('/') || name.include?('\\')
    return failure("Filename contains null bytes") if name.include?("\x00")

    ext = File.extname(name).downcase
    return failure("Dangerous file extension: #{ext}") if DANGEROUS_EXTENSIONS.include?(ext)

    success(name)
  end

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
