class ResumableUploadService < ApplicationService
  MAX_RETRIES = 3

  def initialize(upload_id:, chunk_number:, total_chunks:, chunk_data:, filename:, checksum: nil)
    @upload_id = upload_id
    @chunk_number = chunk_number
    @total_chunks = total_chunks
    @chunk_data = chunk_data
    @filename = filename
    @expected_checksum = checksum
  end

  def call
    validate_params!
    verify_checksum! if @expected_checksum
    store_chunk_with_retry
    record_chunk

    if all_chunks_received?
      assemble_file
    else
      Result.success(
        upload_id: @upload_id,
        chunk_number: @chunk_number,
        status: 'partial',
        received: received_count,
        total: @total_chunks,
        progress: progress_percentage
      )
    end
  rescue => e
    Rails.logger.error("ResumableUploadService failed: #{e.message}")
    mark_chunk_failed
    Result.failure(e.message)
  end

  # Get upload progress for a given upload_id
  def self.progress(upload_id)
    chunks = UploadChunk.for_upload(upload_id)
    return nil if chunks.empty?

    total = chunks.first.total_chunks
    received = chunks.completed.count
    {
      upload_id: upload_id,
      received: received,
      total: total,
      progress: ((received.to_f / total) * 100).round(2),
      missing: missing_chunks(upload_id, total)
    }
  end

  # Clean uploads older than the configured stale threshold
  def self.cleanup_stale
    stale_hours = Rails.application.config.x.storage.stale_upload_hours
    stale_ids = UploadChunk.where('uploaded_at < ?', stale_hours.hours.ago)
                           .distinct.pluck(:upload_id)

    stale_ids.each do |upload_id|
      cleanup_upload(upload_id)
    end

    stale_ids.size
  end

  private

  def validate_params!
    raise ArgumentError, "Missing upload_id" unless @upload_id.present?
    raise ArgumentError, "Invalid chunk_number" unless @chunk_number.is_a?(Integer) && @chunk_number >= 0
    raise ArgumentError, "Invalid total_chunks" unless @total_chunks.is_a?(Integer) && @total_chunks > 0
    raise ArgumentError, "chunk_number exceeds total_chunks" if @chunk_number >= @total_chunks
    raise ArgumentError, "Missing chunk data" unless @chunk_data
  end

  def verify_checksum!
    actual = Digest::MD5.hexdigest(chunk_content)
    unless actual == @expected_checksum
      raise ArgumentError, "Checksum mismatch: expected #{@expected_checksum}, got #{actual}"
    end
  end

  def store_chunk_with_retry
    retries = 0
    begin
      FileUtils.mkdir_p(chunks_dir)
      chunk_path = File.join(chunks_dir, "chunk_#{@chunk_number.to_s.rjust(6, '0')}")

      # Path traversal guard
      unless File.expand_path(chunk_path).start_with?(File.expand_path(chunks_dir))
        raise SecurityError, "Path traversal detected"
      end

      File.open(chunk_path, 'wb') do |f|
        f.write(chunk_content)
      end
    rescue IOError, Errno::ENOSPC => e
      retries += 1
      raise e if retries >= MAX_RETRIES
      sleep(0.5 * retries)
      retry
    end
  end

  def record_chunk
    chunk = UploadChunk.find_or_initialize_by(upload_id: @upload_id, chunk_number: @chunk_number)
    chunk.update!(
      total_chunks: @total_chunks,
      checksum: @expected_checksum || Digest::MD5.hexdigest(chunk_content),
      filename: @filename,
      status: 'uploaded',
      uploaded_at: Time.current
    )
  end

  def mark_chunk_failed
    chunk = UploadChunk.find_or_initialize_by(upload_id: @upload_id, chunk_number: @chunk_number)
    chunk.update(status: 'failed', total_chunks: @total_chunks, filename: @filename)
  rescue => e
    Rails.logger.error("Failed to mark chunk as failed: #{e.message}")
  end

  def all_chunks_received?
    received_count == @total_chunks
  end

  def received_count
    UploadChunk.for_upload(@upload_id).completed.count
  end

  def progress_percentage
    ((received_count.to_f / @total_chunks) * 100).round(2)
  end

  def assemble_file
    output_dir = File.join(Rails.root, 'tmp', 'assembled')
    FileUtils.mkdir_p(output_dir)

    safe_name = File.basename(@filename)
    output_path = File.join(output_dir, "#{@upload_id}_#{safe_name}")

    File.open(output_path, 'wb') do |out|
      @total_chunks.times do |i|
        chunk_path = File.join(chunks_dir, "chunk_#{i.to_s.rjust(6, '0')}")
        raise "Missing chunk #{i}" unless File.exist?(chunk_path)
        out.write(File.binread(chunk_path))
      end
    end

    # Clean up chunks
    FileUtils.rm_rf(chunks_dir)
    UploadChunk.for_upload(@upload_id).delete_all

    Result.success(
      upload_id: @upload_id,
      status: 'complete',
      path: output_path,
      filename: safe_name,
      size: File.size(output_path)
    )
  end

  def chunk_content
    @chunk_content ||= if @chunk_data.respond_to?(:read)
                         data = @chunk_data.read
                         @chunk_data.rewind if @chunk_data.respond_to?(:rewind)
                         data
                       else
                         @chunk_data.to_s
                       end
  end

  def chunks_dir
    @chunks_dir ||= File.join(Rails.root, 'tmp', 'chunks', @upload_id)
  end

  def self.missing_chunks(upload_id, total)
    received = UploadChunk.for_upload(upload_id).completed.pluck(:chunk_number)
    (0...total).to_a - received
  end

  def self.cleanup_upload(upload_id)
    chunks_dir = File.join(Rails.root, 'tmp', 'chunks', upload_id)
    FileUtils.rm_rf(chunks_dir) if Dir.exist?(chunks_dir)
    UploadChunk.for_upload(upload_id).delete_all
  end
end
