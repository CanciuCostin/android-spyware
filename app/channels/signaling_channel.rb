# WebRTC Signaling Channel — pure relay between Admin browser and Android device.
#
# Signaling flow (WebRTC establishment):
#   1. Admin calls start_stream → broadcasted to device stream.
#   2. Device captures camera/mic, creates SDP offer → relayed to admin stream.
#   3. Admin creates SDP answer → relayed to device stream.
#   4. Both sides exchange ICE candidates via ice_candidate → routed by target param.
#   5. Once ICE completes, media flows peer-to-peer (bypasses this server entirely).
#
# Stream topology:
#   - Admin subscribes to: "signaling_admin_<device_id>"  (receives offers + ICE from device)
#   - Device subscribes to: "signaling_device_<device_id>" (receives answers + ICE from admin)
#
# Security note: SDP and ICE candidate payloads are passed through unvalidated
# because they contain opaque WebRTC protocol data. Only device_id is sanitized.
class SignalingChannel < ApplicationCable::Channel
  def subscribed
    @device_id = sanitize_device_id(params[:device_id])
    @is_admin = connection.current_user_type == :admin
    
    # Admin subscribes to device-specific signaling channel
    # Device stream: "signaling_device_#{device_id}"
    # Admin stream: "signaling_admin_#{device_id}"
    
    if @is_admin
      stream_from "signaling_admin_#{@device_id}"
      Rails.logger.info "[SignalingChannel] Admin subscribed to device #{@device_id}"
    else
      stream_from "signaling_device_#{@device_id}"
      Rails.logger.info "[SignalingChannel] Device #{@device_id} subscribed to signaling"
    end
  end

  def unsubscribed
    if @is_admin
      Rails.logger.info "[SignalingChannel] Admin unsubscribed from device #{@device_id}"
    else
      Rails.logger.info "[SignalingChannel] Device #{@device_id} unsubscribed from signaling"
    end
  end

  # Receive SDP offer from Android device (to Admin)
  def offer(data)
    sdp = data['sdp']
    device_id = data['device_id'] || @device_id

    Rails.logger.info "[SignalingChannel] Received offer from device #{device_id}"

    ActionCable.server.broadcast(
      "signaling_admin_#{device_id}",
      {
        type: 'offer',
        sdp: sdp,
        device_id: device_id
      }
    )
  end

  # Receive SDP answer from Admin browser (to Device)
  def answer(data)
    sdp = data['sdp']
    device_id = data['device_id'] || @device_id

    Rails.logger.info "[SignalingChannel] Received answer for device #{device_id}"

    ActionCable.server.broadcast(
      "signaling_device_#{device_id}",
      {
        type: 'answer',
        sdp: sdp
      }
    )
  end

  # Exchange ICE candidates for NAT traversal.
  # When 'target' is not specified, we infer the recipient from the sender's role:
  #   - Admin sends ICE → target defaults to 'device'
  #   - Device sends ICE → target defaults to 'admin'
  def ice_candidate(data)
    candidate = data['candidate']
    device_id = data['device_id'] || @device_id
    target = data['target'] || (@is_admin ? 'device' : 'admin')

    Rails.logger.info "[SignalingChannel] Received ICE candidate for device #{device_id}, target: #{target}"

    # Route to appropriate recipient
    stream_name = target == 'admin' ? "signaling_admin_#{device_id}" : "signaling_device_#{device_id}"
    
    ActionCable.server.broadcast(
      stream_name,
      {
        type: 'ice_candidate',
        candidate: candidate
      }
    )
  end

  # Admin initiates WebRTC stream request
  def start_stream(data)
    device_id = data['device_id'] || @device_id
    stream_type = data['stream_type'] || 'camera'

    Rails.logger.info "[SignalingChannel] Admin requesting stream (#{stream_type}) from device #{device_id}"

    ActionCable.server.broadcast(
      "signaling_device_#{device_id}",
      {
        type: 'start_stream_request',
        stream_type: stream_type
      }
    )
  end

  # Admin stops the stream
  def stop_stream(data)
    device_id = data['device_id'] || @device_id

    Rails.logger.info "[SignalingChannel] Admin stopping stream for device #{device_id}"

    ActionCable.server.broadcast(
      "signaling_device_#{device_id}",
      {
        type: 'stop_stream_request'
      }
    )
  end

  private

  def sanitize_device_id(device_id)
    device_id.to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
  end
end
