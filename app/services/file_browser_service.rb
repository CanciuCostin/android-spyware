# frozen_string_literal: true

# Service for handling file browser operations (upload, download, etc.)
class FileBrowserService < ApplicationService
  MAX_FILE_SIZE = 50.megabytes
  CHUNK_SIZE = 5.megabytes
  
  # Upload file directly (for small files)
  def self.upload_file_direct(smartphone, file, destination_path)
    validate_file_size!(file)
    
    # Read file content and encode as base64
    file_content = file.read
    encoded_content = Base64.strict_encode64(file_content)
    
    # Send command to device
    command_params = {
      filename: sanitize_filename(file.original_filename),
      destination_path: sanitize_path(destination_path),
      content_base64: encoded_content,
      size: file.size
    }
    
    # Use CommandSender concern
    pending_command = CommandSender.send_command_async(
      smartphone,
      'upload_file',
      command_params
    )
    
    {
      success: true,
      request_id: pending_command.request_id,
      filename: file.original_filename,
      size: file.size,
      message: 'File upload initiated'
    }
  rescue StandardError => e
    Rails.logger.error "[FileBrowserService] Direct upload error: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end
  
  # Upload file in chunks (for large files)
  def self.upload_file_chunked(smartphone, file, destination_path, upload_id)
    validate_file_size!(file)
    
    total_size = file.size
    total_chunks = (total_size.to_f / CHUNK_SIZE).ceil
    
    Rails.logger.info "[FileBrowserService] Chunked upload started: #{upload_id}, #{total_chunks} chunks"
    
    (0...total_chunks).each do |chunk_index|
      # Read chunk
      file.seek(chunk_index * CHUNK_SIZE)
      chunk_data = file.read(CHUNK_SIZE)
      encoded_chunk = Base64.strict_encode64(chunk_data)
      
      # Send chunk command
      command_params = {
        upload_id: upload_id,
        chunk_index: chunk_index,
        total_chunks: total_chunks,
        filename: sanitize_filename(file.original_filename),
        destination_path: sanitize_path(destination_path),
        chunk_data: encoded_chunk
      }
      
      pending_command = CommandSender.send_command_async(
        smartphone,
        'upload_file_chunk',
        command_params
      )
      
      Rails.logger.info "[FileBrowserService] Chunk #{chunk_index + 1}/#{total_chunks} sent: #{pending_command.request_id}"
    end
    
    {
      success: true,
      upload_id: upload_id,
      filename: file.original_filename,
      size: total_size,
      chunks: total_chunks,
      message: 'Chunked file upload initiated'
    }
  rescue StandardError => e
    Rails.logger.error "[FileBrowserService] Chunked upload error: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end
  
  # Process downloaded file from device
  def self.process_downloaded_file(smartphone, file_data)
    filename = file_data[:filename]
    content_base64 = file_data[:content_base64]
    
    # Decode base64 content
    content = Base64.decode64(content_base64)
    
    # Save to storage
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    safe_filename = "#{timestamp}_#{sanitize_filename(filename)}"
    file_path = Rails.root.join('files', 'downloads', smartphone.device_id, safe_filename)
    
    FileUtils.mkdir_p(File.dirname(file_path))
    File.binwrite(file_path, content)
    
    Rails.logger.info "[FileBrowserService] File downloaded: #{file_path}"
    
    {
      success: true,
      filename: safe_filename,
      path: file_path.to_s,
      size: content.bytesize
    }
  rescue StandardError => e
    Rails.logger.error "[FileBrowserService] Download processing error: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end
  
  private
  
  def self.validate_file_size!(file)
    if file.size > MAX_FILE_SIZE
      raise ArgumentError, "File size exceeds maximum (#{MAX_FILE_SIZE / 1.megabyte}MB)"
    end
  end
  
  def self.sanitize_filename(filename)
    # Remove path separators and dangerous characters
    filename.to_s
            .gsub(%r{[/\\]}, '')
            .gsub(/[^\w\s.\-]/, '_')
            .strip[0..255]
  end
  
  def self.sanitize_path(path)
    # Remove null bytes
    clean_path = path.to_s.gsub("\0", '')
    
    # Remove consecutive slashes
    clean_path = clean_path.gsub(%r{/+}, '/')
    
    # Detect path traversal
    if clean_path.include?('../') || clean_path.include?('..\\')
      raise SecurityError, 'Path traversal attempt detected'
    end
    
    clean_path
  end
end
