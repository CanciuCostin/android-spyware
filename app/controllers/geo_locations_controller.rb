class GeoLocationsController < InheritedResources::Base

  def dump_location
    @smartphone = Smartphone.find(params[:smartphone_id])

    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    processCommand="location_dump"
    commandOutput=start_msf_process(processCommand)
    puts commandOutput

    if commandOutput.any? { |n| n.include? "Lat" }
      latitude=commandOutput.find{|n| n.include? "Lat" }.split(":")[1].strip
      longitude=commandOutput.find{|n| n.include? "Lon" }.split(":")[1].strip
      newLocation=Geo_location.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:lat => latitude,:long => longitude, :smartphone_id => @smartphone.id)
      newLocation.save!
    end

    respond_to do |format|
        format.js { render "dump_location", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
      end
end

  private

    def geo_location_params
      params.require(:geo_location).permit(:date, :lat, :long, :smartphone_id)
    end


end
