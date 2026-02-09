class KeylogChannel < ApplicationCable::Channel
  def subscribed
    stream_from "keylog_stream"
  end

  def unsubscribed
    # Cleanup
  end
end
