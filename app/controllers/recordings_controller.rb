class RecordingsController < InheritedResources::Base

  private

    def recording_params
      params.require(:recording).permit(:date, :duration, :filename, :smartphone_id)
    end

end
