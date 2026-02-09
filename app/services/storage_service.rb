class StorageService < ApplicationService
  class FileNotFound < StandardError; end
  class ConfigError < StandardError; end
  class DuplicateFile < StandardError; end

  def initialize(backend: nil)
    @backend_name = backend || Rails.application.config.x.storage.backend
    @adapter = build_adapter(@backend_name)
  end

  def call
    self
  end

  # Upload a file and track it in the database
  def upload(file_or_path, original_filename:, content_type: nil, metadata: {})
    checksum = compute_checksum(file_or_path)
    key = generate_key(original_filename)
    size = resolve_size(file_or_path)

    result = @adapter.upload(key, file_or_path, metadata: metadata)

    stored_file = StoredFile.create!(
      path: key,
      original_filename: original_filename,
      size: size,
      content_type: content_type,
      checksum: checksum,
      storage_backend: @backend_name,
      storage_key: key,
      reference_count: 1,
      metadata: metadata,
      last_accessed_at: Time.current
    )

    Result.success(stored_file: stored_file, key: key, size: size, checksum: checksum)
  rescue => e
    Rails.logger.error("StorageService upload failed: #{e.message}")
    Result.failure(e.message)
  end

  # Download a file, returns the local file path
  def download(key)
    stored_file = StoredFile.find_by!(storage_key: key)
    stored_file.update(last_accessed_at: Time.current)
    path = @adapter.download(key)
    Result.success(path: path, stored_file: stored_file)
  rescue ActiveRecord::RecordNotFound
    Result.failure("File record not found: #{key}")
  rescue FileNotFound => e
    Result.failure(e.message)
  end

  # Delete a file and its database record
  def delete(key)
    stored_file = StoredFile.find_by(storage_key: key)

    if stored_file && stored_file.reference_count > 1
      stored_file.decrement!(:reference_count)
      return Result.success(message: "Reference count decremented", remaining: stored_file.reference_count)
    end

    @adapter.delete(key)
    stored_file&.destroy
    Result.success(message: "File deleted", key: key)
  rescue => e
    Rails.logger.error("StorageService delete failed: #{e.message}")
    Result.failure(e.message)
  end

  # List files, optionally filtered by prefix
  def list(prefix: nil)
    keys = @adapter.list(prefix: prefix)
    Result.success(files: keys, count: keys.size)
  rescue => e
    Result.failure(e.message)
  end

  # Get a signed/temporary URL for a file
  def signed_url(key, expires_in: nil)
    expires_in ||= Rails.application.config.x.storage.signed_url_expiry
    url = @adapter.signed_url(key, expires_in: expires_in)
    Result.success(url: url, expires_in: expires_in)
  rescue FileNotFound => e
    Result.failure(e.message)
  end

  # Check if a file exists in storage
  def exists?(key)
    @adapter.exists?(key)
  end

  # Get total disk usage
  def disk_usage
    @adapter.disk_usage
  end

  private

  def build_adapter(backend)
    case backend.to_s
    when 'local'
      Storage::LocalAdapter.new
    when 's3'
      Storage::S3Adapter.new
    else
      raise ConfigError, "Unknown storage backend: #{backend}. Use 'local' or 's3'."
    end
  end

  def compute_checksum(file_or_path)
    digest = Digest::SHA256.new
    if file_or_path.respond_to?(:read)
      file_or_path.rewind if file_or_path.respond_to?(:rewind)
      while (chunk = file_or_path.read(8192))
        digest.update(chunk)
      end
      file_or_path.rewind if file_or_path.respond_to?(:rewind)
    else
      File.open(file_or_path.to_s, 'rb') do |f|
        while (chunk = f.read(8192))
          digest.update(chunk)
        end
      end
    end
    digest.hexdigest
  end

  def generate_key(filename)
    safe_name = File.basename(filename).gsub(/[^a-zA-Z0-9._-]/, '_')
    date_prefix = Time.current.strftime('%Y/%m/%d')
    "#{date_prefix}/#{SecureRandom.uuid}/#{safe_name}"
  end

  def resolve_size(file_or_path)
    if file_or_path.respond_to?(:size)
      file_or_path.size
    elsif File.exist?(file_or_path.to_s)
      File.size(file_or_path.to_s)
    else
      0
    end
  end
end
