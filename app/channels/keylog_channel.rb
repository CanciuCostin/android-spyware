class KeylogChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]
    reject unless device_id.present?
    stream_from "keylog_stream_#{device_id}"
  end

  def unsubscribed
    # Cleanup
  end
end
