class ClipboardChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]
    reject unless device_id.present?
    stream_from "clipboard_stream_#{device_id}"
  end

  def unsubscribed
    # cleanup
  end
end
