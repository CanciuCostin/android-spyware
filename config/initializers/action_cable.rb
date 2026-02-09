# frozen_string_literal: true

# Action Cable performance tuning
Rails.application.configure do
  config.action_cable.worker_pool_size = ENV.fetch('ACTION_CABLE_WORKERS', 4).to_i

  # In development/test, disable CSRF for WebSocket connections because device
  # clients authenticate via token (X-Device-Token header) rather than cookies.
  # In production, restrict origins to the admin dashboard host.
  if Rails.env.production?
    config.action_cable.allowed_request_origins = [
      ENV.fetch('ALLOWED_CABLE_ORIGIN', "https://#{ENV.fetch('APP_HOST', 'localhost')}")
    ]
  else
    config.action_cable.disable_request_forgery_protection = true
  end
end

# Connection limits and message size constraints
ActionCable.server.config.tap do |cfg|
  # Worker pool for processing incoming messages
  cfg.worker_pool_size = ENV.fetch('ACTION_CABLE_WORKERS', 4).to_i

  # Connection keepalive — interval between server-side pings (seconds).
  # Clients that miss 3 consecutive pings are considered stale.
  cfg.connection_class = -> { ApplicationCable::Connection }
end

# Global message size limit enforced via middleware
module ActionCable
  module Connection
    module MessageSizeLimit
      MAX_MESSAGE_SIZE = ENV.fetch('WS_MAX_MESSAGE_SIZE', 1_048_576).to_i # 1 MB default

      def receive(websocket_message)
        if websocket_message.is_a?(String) && websocket_message.bytesize > MAX_MESSAGE_SIZE
          Rails.logger.warn(
            "[ActionCable] Message rejected: #{websocket_message.bytesize} bytes " \
            "(limit: #{MAX_MESSAGE_SIZE})"
          )
          transmit({ error: 'message_too_large', max_size: MAX_MESSAGE_SIZE }.to_json)
          return
        end

        super
      end
    end
  end
end

# Prepend the size-limit check after application loads
Rails.application.config.after_initialize do
  if defined?(ApplicationCable::Connection)
    ApplicationCable::Connection.prepend(ActionCable::Connection::MessageSizeLimit)
  end
end
