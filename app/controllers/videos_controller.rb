class VideosController < InheritedResources::Base

  private

    def video_params
      params.require(:video).permit(:date, :duration, :filename, :smartphone_id)
    end

end
