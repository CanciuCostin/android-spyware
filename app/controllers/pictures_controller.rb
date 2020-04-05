class PicturesController < InheritedResources::Base

  private

    def picture_params
      params.require(:picture).permit(:date, :duration, :filename, :smartphone_id)
    end

end
