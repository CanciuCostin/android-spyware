class FileUploadService < ApplicationService
  MAX_TOTAL_CHUNKS = 10_000
  MAX_CHUNK_SIZE = 10.megabytes
  
  def initialize(device, upload_params)
    @device = device
    @upload_id = upload_params[:upload_id]
    @chunk_index = upload_params[:chunk_index].to_i
    @total_chunks = upload_params[:total_chunks].to_i
    @file_chunk = upload_params[:file]
    @filename = upload_params[:filename]
  end
  
  def call
    validate_params!
    store_chunk
    update_metadata
    
    Result.success(
      upload_id: @upload_id,
      chunk_index: @chunk_index,
      message: "Chunk #{@chunk_index + 1}/#{@total_chunks} uploaded",
      progress: progress_percentage
    )
  rescue => e
    Rails.logger.error("File upload failed: #{e.message}")
    cleanup_failed_upload
    Result.failure(e.message)
  end
  
  private
  
  def validate_params!
    raise ArgumentError, "Missing parameters" unless @upload_id && @file_chunk && @filename
    raise ArgumentError, "Invalid upload_id format" unless @upload_id =~ /\A[a-f0-9\-]{36}\z/i
    raise ArgumentError, "Too many chunks (max #{MAX_TOTAL_CHUNKS})" if @total_chunks > MAX_TOTAL_CHUNKS
    raise ArgumentError, "Invalid chunk index" unless @chunk_index >= 0 && @chunk_index < @total_chunks
    raise ArgumentError, "Chunk too large" if @file_chunk.size > MAX_CHUNK_SIZE
  end
  
  def store_chunk
    FileUtils.mkdir_p(upload_dir)
    
    # Verify path is within upload_dir
    unless File.expand_path(upload_path).start_with?(File.expand_path(upload_dir))
      raise SecurityError, "Invalid path"
    end
    
    File.open(upload_path, 'ab') do |f|
      f.write(@file_chunk.read)
    end
  end
  
  def update_metadata
    existing_chunks = []
    
    if File.exist?(metadata_path)
      begin
        existing_metadata = JSON.parse(File.read(metadata_path))
        existing_chunks = existing_metadata['chunks_received'] || []
      rescue JSON::ParserError
        # Ignore corrupted metadata, will be overwritten
      end
    end
    
    existing_chunks << @chunk_index unless existing_chunks.include?(@chunk_index)
    
    metadata = {
      upload_id: @upload_id,
      filename: @filename,
      total_chunks: @total_chunks,
      last_chunk_index: @chunk_index,
      chunks_received: existing_chunks.sort
    }
    
    File.write(metadata_path, JSON.generate(metadata))
  end
  
  def progress_percentage
    if File.exist?(metadata_path)
      metadata = JSON.parse(File.read(metadata_path))
      chunks_received = metadata['chunks_received'] || []
      ((chunks_received.size.to_f / @total_chunks) * 100).round(2)
    else
      0.0
    end
  end
  
  def cleanup_failed_upload
    FileUtils.rm_rf(upload_path) if File.exist?(upload_path)
    FileUtils.rm_f(metadata_path) if File.exist?(metadata_path)
  end
  
  def upload_dir
    @upload_dir ||= File.join(Rails.root, 'tmp', 'uploads')
  end
  
  def upload_path
    @upload_path ||= File.join(upload_dir, @upload_id)
  end
  
  def metadata_path
    @metadata_path ||= "#{upload_path}.meta"
  end
end
