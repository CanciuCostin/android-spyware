class FileFinalizationService < ApplicationService
  def initialize(upload_id, filename)
    @upload_id = upload_id
    @filename = filename
  end
  
  def call
    validate_params!
    verify_upload_exists!
    verify_all_chunks_received!
    finalize_upload
    
    Result.success(
      upload_id: @upload_id,
      filename: @safe_filename,
      path: @dest_path,
      size: File.size(@dest_path),
      message: "Upload completed successfully"
    )
  rescue => e
    Rails.logger.error("File finalization failed: #{e.message}")
    Result.failure(e.message)
  end
  
  private
  
  def validate_params!
    raise ArgumentError, "Missing parameters" unless @upload_id && @filename
  end
  
  def verify_upload_exists!
    raise ArgumentError, "Upload not found" unless File.exist?(upload_path)
    raise ArgumentError, "Upload metadata not found" unless File.exist?(metadata_path)
  end
  
  def verify_all_chunks_received!
    metadata = JSON.parse(File.read(metadata_path))
    expected_chunks = (0...metadata['total_chunks'].to_i).to_a
    received_chunks = metadata['chunks_received']
    
    missing_chunks = expected_chunks - received_chunks
    unless missing_chunks.empty?
      raise ArgumentError, "Missing chunks: #{missing_chunks.join(', ')}"
    end
  end
  
  def finalize_upload
    FileUtils.mkdir_p(dest_dir)
    
    @safe_filename = File.basename(@filename)

    dangerous_extensions = %w[.exe .bat .cmd .com .scr .pif .vbs .vbe .js .jse .wsf .wsh .msi .ps1 .psm1 .reg .inf .cpl .hta .rb .sh .py .pl .php .cgi .jsp .asp .aspx]
    ext = File.extname(@safe_filename).downcase
    if dangerous_extensions.include?(ext)
      Rails.logger.warn("[FileFinalization] Blocked dangerous file: #{@safe_filename}")
      raise ArgumentError, "File type not allowed: #{ext}"
    end

    @dest_path = File.join(dest_dir, @safe_filename)
    
    FileUtils.mv(upload_path, @dest_path)
    File.delete(metadata_path) if File.exist?(metadata_path)
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
  
  def dest_dir
    @dest_dir ||= File.join(Rails.root, 'files', 'uploads')
  end
end
