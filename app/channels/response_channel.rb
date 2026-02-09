class ResponseChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]
    reject unless device_id.present?
    stream_from "response_channel_#{device_id}"
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
