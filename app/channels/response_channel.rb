class ResponseChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user_type == :admin
    device_id = params[:device_id]
    reject unless device_id.present?
    stream_from "response_channel_#{device_id}"
  end

  def unsubscribed
    # Cleanup
  end

  def receive(data)
    ResponseProcessor.process(data, device_id: params[:device_id])
  rescue StandardError => e
    Rails.logger.error "[ResponseChannel] Error processing response: #{e.message}"
    transmit(type: 'error', message: "Processing failed: #{e.message}")
  end
end
