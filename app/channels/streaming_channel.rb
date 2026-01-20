# WebRTC Signaling Channel for Live Camera/Microphone Streaming
class StreamingChannel < ApplicationCable::Channel
  def subscribed
    stream_from "streaming_#{params[:device_id]}"
    Rails.logger.info "[StreamingChannel] Device #{params[:device_id]} subscribed"
  end

  def unsubscribed
    Rails.logger.info "[StreamingChannel] Device #{params[:device_id]} unsubscribed"
  end

  # Receive SDP offer from Android device
  def offer(data)
    ActionCable.server.broadcast(
      "streaming_#{params[:device_id]}_admin",
      { type: 'offer', sdp: data['sdp'], device_id: params[:device_id] }
    )
  end

  # Receive SDP answer from Admin browser
  def answer(data)
    ActionCable.server.broadcast(
      "streaming_#{params[:device_id]}",
      { type: 'answer', sdp: data['sdp'] }
    )
  end

  # ICE candidate exchange
  def ice_candidate(data)
    target = data['target'] == 'device' ? params[:device_id] : "#{params[:device_id]}_admin"
    ActionCable.server.broadcast(
      "streaming_#{target}",
      { type: 'ice_candidate', candidate: data['candidate'] }
    )
  end

  # Admin requests to start streaming
  def start_stream(data)
    stream_type = data['stream_type'] || 'camera' # camera, microphone, both
    ActionCable.server.broadcast(
      "streaming_#{params[:device_id]}",
      { type: 'start_stream', stream_type: stream_type }
    )
  end

  # Admin requests to stop streaming
  def stop_stream(data)
    ActionCable.server.broadcast(
      "streaming_#{params[:device_id]}",
      { type: 'stop_stream' }
    )
  end
end
