module Api
  class ContactsController < Api::BaseController
    def upload_dump
      device_id = extract_device_id
      return unless device_id
      
      smartphone = find_or_create_smartphone(device_id)
      
      if params[:file].present?
        return unless reject_oversize!(params[:file].size, 'contacts upload')
        filename = "contacts_#{sanitize_device_id(device_id)}–#{Time.now.to_i}.json"
        filepath = secure_filepath('files/dumps/contacts', filename)
        
        FileUtils.mkdir_p(File.dirname(filepath))
        File.open(filepath, 'wb') { |f| f.write(params[:file].read) }
        
        smartphone.contacts.create!(
          filename: filename,
          date: Date.today.to_s
        )
      elsif params[:data].present?
        payload = params[:data].to_json
        return unless reject_oversize!(payload.bytesize, 'contacts upload')
        filename = "contacts_#{sanitize_device_id(device_id)}_#{Time.now.to_i}.json"
        filepath = secure_filepath('files/dumps/contacts', filename)
        
        FileUtils.mkdir_p(File.dirname(filepath))
        File.write(filepath, payload)
        
        smartphone.contacts.create!(
          filename: filename,
          date: Date.today.to_s
        )
      end
      
      render json: { status: 'success', message: 'Contacts saved' }, status: :ok
    rescue => e
      Rails.logger.error("Contacts Upload Error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
  end
end
