class ClipboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "clipboard_stream"
  end

  def unsubscribed
    # cleanup
  end
end
