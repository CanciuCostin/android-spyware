module Api
  class CallLogsController < Api::BaseController
    def upload_dump
      device_id = extract_device_id
      return unless device_id
      
      smartphone = find_or_create_smartphone(device_id)
      
      if params[:file].present?
        return unless reject_oversize!(params[:file].size, 'call logs upload')
        filename = "calls_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = secure_filepath('files/dumps/calls', filename)
        
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.call_logs.create!(
          filename: filename,
          date: Date.today
        )
      elsif params[:data].present?
        payload = params[:data].to_json
        return unless reject_oversize!(payload.bytesize, 'call logs upload')
        filename = "calls_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = secure_filepath('files/dumps/calls', filename)
        
        FileUtils.mkdir_p(File.dirname(filepath))
        File.write(filepath, payload)
        
        smartphone.call_logs.create!(
          filename: filename,
          date: Date.today
        )
      end
      
      render json: { status: 'success', message: 'Call logs saved' }, status: :ok
    rescue => e
      Rails.logger.error("CallLogs Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
  end
end
