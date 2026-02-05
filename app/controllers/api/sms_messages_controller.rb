module Api
  class SmsMessagesController < Api::BaseController
    def upload_dump
      device_id = params[:device_id] || request.headers['X-Device-ID']
      return render json: { error: 'Missing device_id' }, status: :bad_request if device_id.blank?
      
      smartphone = find_or_create_smartphone(device_id)
      
      # Save file if present
      if params[:file].present?
        return unless reject_oversize!(params[:file].size, 'sms upload')
        filename = "sms_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = Rails.root.join('files', 'dumps', 'sms', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.sms_messages.create!(
          filename: filename,
          date: Date.today
        )
      elsif params[:data].present?
        payload = params[:data].to_json
        return unless reject_oversize?(payload.bytesize, 'sms upload')
        filename = "sms_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = Rails.root.join('files', 'dumps', 'sms', filename)
        FileUtils.mkdir_p(File.dirname(filepath))
        File.write(filepath, payload)
        
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
    
  end
end
