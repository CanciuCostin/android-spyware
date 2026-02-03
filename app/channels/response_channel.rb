class ResponseChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'response_channel'
  end

  def unsubscribed
    # Cleanup
  end

  def receive(data)
    # Process response from Android device
    ResponseProcessor.process(data)
  end
end
