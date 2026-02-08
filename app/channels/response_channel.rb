class ResponseChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'response_channel'
  end

  def unsubscribed
    # Cleanup
  end

  def receive(data)
    ResponseProcessor.process(data)
  rescue StandardError => e
    Rails.logger.error "[ResponseChannel] Error processing response: #{e.message}"
  end
end
