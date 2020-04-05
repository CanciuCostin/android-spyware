class ScreenshotsController < InheritedResources::Base

  private

    def screenshot_params
      params.require(:screenshot).permit(:date, :duration, :filename, :smartphone_id)
    end

end
