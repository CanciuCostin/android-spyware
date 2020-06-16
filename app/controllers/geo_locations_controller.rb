class GeoLocationsController < InheritedResources::Base

  def dump_location
    @@nrRunningProcesses+=1
    @smartphone = Smartphone.find(params[:smartphone_id])
    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    processCommand="geolocate"
    commandOutput=start_msf_process(processCommand)

    if commandOutput.any? { |n| n.include? "Lat" }
      latitude=commandOutput[0].split("\n").find{|n| n.include? "Lat" }.split(":")[1].strip
      longitude=commandOutput[0].split("\n").find{|n| n.include? "Lon" }.split(":")[1].strip
      newLocation=GeoLocation.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:lat => latitude,:long => longitude, :smartphone_id => @smartphone.id)
      newLocation.save!
    end

    respond_to do |format|
        format.js { render "dump_location", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
      end

      @@nrFinishedProcesses+=1
      @@nrRunningProcesses-=1
end

  private

    def geo_location_params
      params.require(:geo_location).permit(:date, :lat, :long, :smartphone_id)
    end


end
