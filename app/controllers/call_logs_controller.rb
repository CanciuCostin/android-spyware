class CallLogsController < InheritedResources::Base

  private

    def call_log_params
      params.require(:call_log).permit(:date, :source, :destination, :duration, :filename, :smartphone_id)
    end

end
