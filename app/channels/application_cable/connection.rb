module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_type, :current_identifier

    def connect
      device_id = request.params[:device_id].presence || request.headers['X-Device-ID'].presence

      if device_id.present?
        self.current_identifier = device_id
        self.current_user_type = :device
      elsif env['warden']&.user(:admin_user)
        self.current_identifier = env['warden'].user(:admin_user).email
        self.current_user_type = :admin
      else
        # Accept anonymous browser connections
        self.current_identifier = "anon_#{SecureRandom.hex(4)}"
        self.current_user_type = :admin
      end

      logger.info "[ActionCable] #{current_user_type} '#{current_identifier}' connected"
    end
  end
end
