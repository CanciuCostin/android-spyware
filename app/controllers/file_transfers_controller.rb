class FileTransfersController < ApplicationController
  include ErrorHandler
  include ResponseFormatter
  
  skip_before_action :verify_authenticity_token, only: [:upload_chunk, :finalize_upload]
  before_action :authenticate_device_or_admin!
  before_action :set_device, only: [:upload_chunk, :finalize_upload]
  
  def upload_chunk
    result = FileUploadService.call(@device, upload_params)
    
    if result.success?
      render json: {
        success: true,
        upload_id: result.value[:upload_id],
        chunk_index: result.value[:chunk_index],
        message: result.value[:message],
        progress: result.value[:progress]
      }, status: :ok
    else
      render_error(result.error)
    end
  end
  
  def finalize_upload
    result = FileFinalizationService.call(params[:upload_id], params[:filename])
    
    if result.success?
      render json: {
        success: true,
        upload_id: result.value[:upload_id],
        filename: result.value[:filename],
        path: result.value[:path],
        size: result.value[:size],
        message: result.value[:message]
      }, status: :ok
    else
      render_error(result.error)
    end
  end
  
  # Optional: cleanup for abandoned uploads (can be called periodically)
  def cleanup_expired_uploads
    upload_dir = File.join(Rails.root, 'tmp', 'uploads')
    return unless Dir.exist?(upload_dir)
    
    # Remove uploads older than 24 hours
    Dir.glob("#{upload_dir}/*").each do |upload_path|
      if File.mtime(upload_path) < 24.hours.ago
        FileUtils.rm_rf(upload_path)
        metadata_path = "#{upload_path}.meta"
        FileUtils.rm_f(metadata_path) if File.exist?(metadata_path)
      end
    end
    
    render json: { success: true, message: 'Cleanup completed' }, status: :ok
  end
  
  private
  
  def set_device
    # Try to find device from params, or use a default/guest device
    @device = params[:device_id] ? Smartphone.find(params[:device_id]) : nil
  rescue ActiveRecord::RecordNotFound
    @device = nil
  end
  
  def upload_params
    params.permit(:upload_id, :chunk_index, :total_chunks, :file, :filename)
  end
  
  # SECURITY: Authenticate either admin user or device with valid token
  def authenticate_device_or_admin!
    # Allow if admin user is logged in
    return if respond_to?(:current_admin_user) && current_admin_user.present?
    
    # Otherwise verify device token
    device_token = request.headers['X-Device-Token']
    expected_token = ENV['DEVICE_AUTH_TOKEN']
    
    # If DEVICE_AUTH_TOKEN not set, reject all non-admin requests
    if expected_token.blank?
      Rails.logger.error "[FileTransfersController] DEVICE_AUTH_TOKEN not configured"
      return render json: { error: 'Unauthorized' }, status: :unauthorized
    end
    
    # Use constant-time comparison to prevent timing attacks
    unless device_token.present? && ActiveSupport::SecurityUtils.secure_compare(device_token, expected_token)
      Rails.logger.warn "[FileTransfersController] Invalid or missing device token"
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
