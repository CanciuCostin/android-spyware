module Api
  class FileBrowserController < Api::BaseController
    include CommandSender
    include ErrorHandler
    include ResponseFormatter
    
    before_action :authenticate_admin_user!, except: [:receive]
    before_action :set_smartphone, only: [:index, :download, :upload, :delete, :preview, :rename, :move, :search]
    before_action :validate_file_path, only: [:download, :delete, :preview]

    # Device sends response here
    def receive
      device_id = params[:device_id]
      return head :bad_request if device_id.blank?

      # Android sends "action" in JSON body, but Rails reserves params[:action] for controller action
      raw_action = request.request_parameters["action"] rescue nil
      browse_action = params[:browse_action] || params[:file_action] || raw_action || "list"
      cache_key = "file_browser:#{device_id}"

      Rails.cache.write(cache_key, {
        action: browse_action,
        path: params[:path],
        entries: params[:entries],
        content_base64: params[:content_base64],
        filename: params[:filename],
        error: params[:error],
        received_at: Time.current.iso8601
      }, expires_in: 1.hour)

      # Broadcast to dashboard for real-time update
      ActionCable.server.broadcast("file_browser_stream", {
        device_id: device_id,
        action: browse_action,
        path: params[:path],
        entries: params[:entries],
        filename: params[:filename],
        timestamp: Time.current.iso8601
      }) rescue nil

      head :ok
    end
    
    # GET /api/smartphones/:smartphone_id/files
    # List directory contents
    def index
      path = params[:path] || '/sdcard'
      recursive = params[:recursive] == 'true'
      
      pending_command = send_command_async(
        @smartphone,
        'list_files',
        {
          path: sanitize_path(path),
          recursive: recursive
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File listing command sent',
        path: path
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] List files error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # GET /api/smartphones/:smartphone_id/files/download
    # Download file from device
    def download
      path = params[:path]
      
      pending_command = send_command_async(
        @smartphone,
        'download_file',
        {
          path: sanitize_path(path)
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File download command sent',
        path: path
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Download file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # POST /api/smartphones/:smartphone_id/files/upload
    # Upload file to device
    def upload
      unless params[:file].present?
        return render_error('No file provided', :bad_request)
      end
      
      destination_path = params[:destination_path] || '/sdcard/Download'
      file = params[:file]
      
      # Use chunked upload for large files
      if file.size > 5.megabytes
        upload_id = SecureRandom.uuid
        result = FileBrowserService.upload_file_chunked(
          @smartphone,
          file,
          destination_path,
          upload_id
        )
      else
        result = FileBrowserService.upload_file_direct(
          @smartphone,
          file,
          destination_path
        )
      end
      
      if result[:success]
        render json: result, status: :ok
      else
        render_error(result[:error], :internal_server_error)
      end
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Upload file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # DELETE /api/smartphones/:smartphone_id/files
    # Delete file or directory
    def delete
      path = params[:path]
      
      pending_command = send_command_async(
        @smartphone,
        'delete_file',
        {
          path: sanitize_path(path)
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File deletion command sent',
        path: path
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Delete file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # GET /api/smartphones/:smartphone_id/files/preview
    # Preview file content (text, images)
    def preview
      path = params[:path]
      
      pending_command = send_command_async(
        @smartphone,
        'preview_file',
        {
          path: sanitize_path(path),
          max_size: 1.megabyte # Only preview files under 1MB
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File preview command sent',
        path: path
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Preview file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # POST /api/smartphones/:smartphone_id/files/rename
    # Rename file or directory
    def rename
      old_path = params[:old_path]
      new_name = params[:new_name]
      
      unless old_path.present? && new_name.present?
        return render_error('Missing old_path or new_name', :bad_request)
      end
      
      pending_command = send_command_async(
        @smartphone,
        'rename_file',
        {
          old_path: sanitize_path(old_path),
          new_name: sanitize_filename(new_name)
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File rename command sent'
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Rename file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # POST /api/smartphones/:smartphone_id/files/move
    # Move file or directory
    def move
      source_path = params[:source_path]
      destination_path = params[:destination_path]
      
      unless source_path.present? && destination_path.present?
        return render_error('Missing source_path or destination_path', :bad_request)
      end
      
      pending_command = send_command_async(
        @smartphone,
        'move_file',
        {
          source_path: sanitize_path(source_path),
          destination_path: sanitize_path(destination_path)
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File move command sent'
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Move file error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    # GET /api/smartphones/:smartphone_id/files/search
    # Search files by name pattern
    def search
      query = params[:query]
      base_path = params[:path] || '/sdcard'
      
      unless query.present?
        return render_error('Missing search query', :bad_request)
      end
      
      pending_command = send_command_async(
        @smartphone,
        'search_files',
        {
          query: sanitize_text(query),
          path: sanitize_path(base_path)
        }
      )
      
      render json: {
        success: true,
        request_id: pending_command.request_id,
        message: 'File search command sent',
        query: query
      }, status: :accepted
    rescue StandardError => e
      Rails.logger.error "[FileBrowserController] Search files error: #{e.message}"
      render_error(e.message, :internal_server_error)
    end
    
    private
    
    def set_smartphone
      @smartphone = Smartphone.find(params[:smartphone_id])
    rescue ActiveRecord::RecordNotFound
      render_error('Device not found', :not_found)
    end
    
    def validate_file_path
      unless params[:path].present?
        render_error('Missing file path', :bad_request)
      end
    end
    
    # SECURITY: Prevent path traversal attacks
    def sanitize_path(path)
      # Remove null bytes
      clean_path = path.to_s.gsub("\0", '')
      
      # Remove consecutive slashes
      clean_path = clean_path.gsub(%r{/+}, '/')
      
      # Detect and reject path traversal attempts
      if clean_path.include?('../') || clean_path.include?('..\\')
        raise SecurityError, 'Path traversal attempt detected'
      end
      
      # Ensure path is absolute for Android
      clean_path = "/#{clean_path}" unless clean_path.start_with?('/')
      
      clean_path
    end
    
    def sanitize_filename(filename)
      # Remove path separators and dangerous characters
      filename.to_s
              .gsub(%r{[/\\]}, '')
              .gsub(/[^\w\s.\-]/, '')
              .strip[0..255]
    end
    
    def sanitize_text(text)
      text.to_s.strip[0..500]
    end
  end
end
