# Channel for admin device notifications (status updates, command responses)
class AdminDevicesChannel < ApplicationCable::Channel
  def subscribed
    reject unless connection.current_user_type == :admin
    stream_from "admin_devices"
    Rails.logger.info "[AdminDevicesChannel] Admin subscribed to device notifications"
  end

  def unsubscribed
    Rails.logger.info "[AdminDevicesChannel] Admin unsubscribed"
  end
end
