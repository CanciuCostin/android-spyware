# frozen_string_literal: true

class FileBrowserResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    action = @response['action'] || @pending_command.command
    
    case action
    when 'list_files'
      process_file_listing
    when 'download_file'
      process_file_download
    when 'upload_file', 'upload_file_chunk'
      process_file_upload
    when 'delete_file'
      process_file_deletion
    when 'preview_file'
      process_file_preview
    when 'rename_file'
      process_file_rename
    when 'move_file'
      process_file_move
    when 'search_files'
      process_file_search
    else
      Rails.logger.warn "[FileBrowserResponseProcessor] Unknown action: #{action}"
      @pending_command.mark_failed("Unknown action: #{action}")
    end
  rescue StandardError => e
    Rails.logger.error "[FileBrowserResponseProcessor] Error: #{e.message}"
    @pending_command.mark_failed(e.message)
  end
  
  private
  
  def process_file_listing
    entries = @response['entries'] || []
    path = @response['path']
    
    # Store in cache for quick retrieval
    cache_key = "file_listing:#{@smartphone.device_id}:#{path}"
    Rails.cache.write(cache_key, {
      entries: entries,
      path: path,
      parent: @response['parent'],
      count: @response['count'],
      timestamp: Time.current
    }, expires_in: 10.minutes)
    
    # Broadcast to ActionCable for real-time UI update
    ActionCable.server.broadcast(
      "file_browser_#{@smartphone.device_id}",
      {
        action: 'list_files',
        path: path,
        entries: entries,
        count: entries.length
      }
    )
    
    @pending_command.mark_completed(@response)
    
    Rails.logger.info "[FileBrowserResponseProcessor] Listed #{entries.length} files in #{path}"
  end
  
  def process_file_download
    filename = @response['filename']
    content_base64 = @response['content_base64']
    size = @response['size']
    
    unless content_base64.present?
      @pending_command.mark_failed('No file content received')
      return
    end
    
    # Process and save the downloaded file
    result = FileBrowserService.process_downloaded_file(
      @smartphone,
      {
        filename: filename,
        content_base64: content_base64
      }
    )
    
    if result[:success]
      # Create a record of the downloaded file
      create_download_record(filename, result[:path], result[:size])
      
      # Broadcast success
      ActionCable.server.broadcast(
        "file_browser_#{@smartphone.device_id}",
        {
          action: 'download_complete',
          filename: filename,
          size: result[:size],
          path: result[:path]
        }
      )
      
      @pending_command.mark_completed(@response.merge(local_path: result[:path]))
      
      Rails.logger.info "[FileBrowserResponseProcessor] Downloaded file: #{filename}"
    else
      @pending_command.mark_failed(result[:error])
    end
  end
  
  def process_file_upload
    filename = @response['filename']
    success = @response['success']
    error = @response['error']
    
    if success
      ActionCable.server.broadcast(
        "file_browser_#{@smartphone.device_id}",
        {
          action: 'upload_complete',
          filename: filename
        }
      )
      
      @pending_command.mark_completed(@response)
      
      Rails.logger.info "[FileBrowserResponseProcessor] Uploaded file: #{filename}"
    else
      @pending_command.mark_failed(error || 'Upload failed')
    end
  end
  
  def process_file_deletion
    path = @response['path']
    success = @response['success']
    error = @response['error']
    
    if success
      ActionCable.server.broadcast(
        "file_browser_#{@smartphone.device_id}",
        {
          action: 'delete_complete',
          path: path
        }
      )
      
      @pending_command.mark_completed(@response)
      
      Rails.logger.info "[FileBrowserResponseProcessor] Deleted: #{path}"
    else
      @pending_command.mark_failed(error || 'Deletion failed')
    end
  end
  
  def process_file_preview
    filename = @response['filename']
    content = @response['content']
    content_type = @response['content_type']
    
    # Store preview in cache
    cache_key = "file_preview:#{@smartphone.device_id}:#{filename}"
    Rails.cache.write(cache_key, {
      content: content,
      content_type: content_type,
      filename: filename,
      timestamp: Time.current
    }, expires_in: 5.minutes)
    
    ActionCable.server.broadcast(
      "file_browser_#{@smartphone.device_id}",
      {
        action: 'preview_ready',
        filename: filename,
        content_type: content_type
      }
    )
    
    @pending_command.mark_completed(@response)
    
    Rails.logger.info "[FileBrowserResponseProcessor] Preview ready: #{filename}"
  end
  
  def process_file_rename
    old_path = @response['old_path']
    new_path = @response['new_path']
    success = @response['success']
    
    if success
      ActionCable.server.broadcast(
        "file_browser_#{@smartphone.device_id}",
        {
          action: 'rename_complete',
          old_path: old_path,
          new_path: new_path
        }
      )
      
      @pending_command.mark_completed(@response)
    else
      @pending_command.mark_failed(@response['error'] || 'Rename failed')
    end
  end
  
  def process_file_move
    source_path = @response['source_path']
    destination_path = @response['destination_path']
    success = @response['success']
    
    if success
      ActionCable.server.broadcast(
        "file_browser_#{@smartphone.device_id}",
        {
          action: 'move_complete',
          source_path: source_path,
          destination_path: destination_path
        }
      )
      
      @pending_command.mark_completed(@response)
    else
      @pending_command.mark_failed(@response['error'] || 'Move failed')
    end
  end
  
  def process_file_search
    results = @response['results'] || []
    query = @response['query']
    
    ActionCable.server.broadcast(
      "file_browser_#{@smartphone.device_id}",
      {
        action: 'search_results',
        query: query,
        results: results,
        count: results.length
      }
    )
    
    @pending_command.mark_completed(@response)
    
    Rails.logger.info "[FileBrowserResponseProcessor] Search found #{results.length} results"
  end
  
  def create_download_record(filename, path, size)
    # Optionally create a database record for tracking downloads
    # This depends on your existing models structure
    Rails.logger.info "[FileBrowserResponseProcessor] Downloaded: #{filename} (#{size} bytes) -> #{path}"
  end
end
