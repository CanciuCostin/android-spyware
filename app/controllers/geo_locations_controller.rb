class GeoLocationsController < InheritedResources::Base

  private

    def geo_location_params
      params.require(:geo_location).permit(:date, :lat, :long, :smartphone_id)
    end

end
