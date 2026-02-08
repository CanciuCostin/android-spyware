class StatisticsChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]
    
    if device_id.present?
      stream_from "statistics:device:#{device_id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def request_update
    device_id = params[:device_id]
    device = Smartphone.find_by(id: device_id)
    
    if device
      stats = StatisticsService.new(device).calculate
      ActionCable.server.broadcast(
        "statistics:device:#{device_id}",
        stats
      )
    end
  end
end
