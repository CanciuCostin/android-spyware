module Api
  class SmsMessagesController < Api::BaseController
    def upload_dump
      device_id = params[:device_id] || request.headers['X-Device-ID']
      return render json: { error: 'Missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      
      # Extract data from file or params
      json_content = nil
      
      if params[:file].present?
        return unless reject_oversize!(params[:file].size, 'sms upload')
        begin
          json_content = params[:file].read
        rescue => e
          return render json: { error: "Failed to read file: #{e.message}" }, status: :unprocessable_entity
        end
      elsif params[:data].present?
        # If data is already parsed by Rails (Array/Hash), convert to JSON string
        payload = params[:data]
        json_content = payload.is_a?(String) ? payload : payload.to_json
        return unless reject_oversize!(json_content.bytesize, 'sms upload')
      else
        return render json: { error: 'No data provided' }, status: :unprocessable_entity
      end

      # Validate JSON structure (must be an Array or Hash of SMS messages)
      begin
        parsed_data = JSON.parse(json_content)
        unless parsed_data.is_a?(Array) || parsed_data.is_a?(Hash)
           return render json: { error: 'Invalid data format: Expected JSON array or hash' }, status: :unprocessable_entity
        end
      rescue JSON::ParserError
        return render json: { error: 'Invalid JSON format' }, status: :unprocessable_entity
      end

      # Save file to disk
      filename = "sms_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
      filepath = Rails.root.join('files', 'dumps', 'sms', filename)
      
      begin
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(json_content) }
        
        smartphone.sms_messages.create!(
          filename: filename,
          date: Date.today
        )
        
        render json: { status: 'success', message: 'SMS data verified and saved' }, status: :ok
      rescue => e
        Rails.logger.error("SMS Save Error: #{e.message}")
        render json: { error: "Failed to save data: #{e.message}" }, status: :internal_server_error
      end
    end
    
  end
end
