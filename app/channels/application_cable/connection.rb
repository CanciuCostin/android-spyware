module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_smartphone

    def connect
      self.current_smartphone = find_verified_smartphone
      logger.info "Smartphone #{current_smartphone.device_id} connected to ActionCable"
    rescue ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end

    private

    def find_verified_smartphone
      device_token = request.params[:token] || request.headers['X-Device-Token']
      device_id = request.params[:device_id] || request.headers['X-Device-ID']

      # Validate token matches expected token
      expected_token = ENV.fetch('DEVICE_TOKEN', 'EagleSpy_X9f2K7mN4pQ8wL3jR6vT1bY5cH0sA')
      
      if device_token.blank? || device_token != expected_token
        logger.warn "ActionCable auth failed: Invalid or missing token"
        raise ActiveRecord::RecordNotFound
      end

      if device_id.blank?
        logger.warn "ActionCable auth failed: Missing device_id"
        raise ActiveRecord::RecordNotFound
      end

      # Find smartphone by device_id
      smartphone = Smartphone.find_by(device_id: device_id)
      
      unless smartphone
        logger.warn "ActionCable auth failed: Device not found (#{device_id})"
        raise ActiveRecord::RecordNotFound
      end

      smartphone
    end
  end
end
