# frozen_string_literal: true

# ActionCable channel for real-time screen mirroring frame streaming.
# Device streams frames to admin viewers via this channel.
class ScreenMirrorChannel < ApplicationCable::Channel
  def subscribed
    @device_id = params[:device_id]
    return reject unless @device_id.present?

    stream_from "screen_mirror_#{@device_id}"
    stream_from "screen_mirror_#{@device_id}_admin"
    Rails.logger.info("[ScreenMirrorChannel] Subscribed: #{@device_id}")
  end

  def unsubscribed
    Rails.logger.info("[ScreenMirrorChannel] Unsubscribed: #{@device_id}")
  end

  # Receive a screen frame from the device and broadcast to admin viewers
  def frame(data)
    ActionCable.server.broadcast(
      "screen_mirror_#{@device_id}_admin",
      {
        type: 'frame',
        data: data['frame_data'],
        timestamp: data['timestamp'] || Time.current.to_i,
        sequence: data['sequence']
      }
    )
  end

  # Admin requests to start screen mirroring
  def start_mirror(data)
    device = find_device
    return broadcast_error('Device not found') unless device
    return broadcast_error('Consent not granted') unless consent_granted?(device)

    service = ScreenMirroringService.new(
      device,
      admin_user: current_admin_user,
      fps: data['fps'],
      quality: data['quality']
    )

    result = service.start_session
    if result.success?
      ActionCable.server.broadcast(
        "screen_mirror_#{@device_id}_admin",
        { type: 'session_started', session: result.value }
      )
    else
      broadcast_error(result.error)
    end
  end

  # Admin requests to stop screen mirroring
  def stop_mirror(_data = {})
    device = find_device
    return broadcast_error('Device not found') unless device

    service = ScreenMirroringService.new(device)
    result = service.stop_session

    ActionCable.server.broadcast(
      "screen_mirror_#{@device_id}_admin",
      { type: 'session_stopped', session: result.value }
    )
  end

  # Admin updates quality/FPS settings mid-session
  def update_settings(data)
    device = find_device
    return broadcast_error('Device not found') unless device

    service = ScreenMirroringService.new(device)
    result = service.update_settings(fps: data['fps'], quality: data['quality'])

    if result.success?
      ActionCable.server.broadcast(
        "screen_mirror_#{@device_id}_admin",
        { type: 'settings_updated', session: result.value }
      )
    else
      broadcast_error(result.error)
    end
  end

  private

  def find_device
    ApkInstallation.find_by(device_id: @device_id) || Smartphone.find_by(device_id: @device_id)
  end

  def consent_granted?(device)
    ConsentService.new(device).check_consent('device_monitoring')
  end

  def current_admin_user
    connection.respond_to?(:current_admin_user) ? connection.current_admin_user&.email : 'system'
  end

  def broadcast_error(message)
    ActionCable.server.broadcast(
      "screen_mirror_#{@device_id}_admin",
      { type: 'error', message: message }
    )
  end
end
