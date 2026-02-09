Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Cache classes for performance (avoids reloading code on every request)
  config.cache_classes = true

  # Do not eager load code on boot (faster startup).
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Concatenate assets for faster page loads
  config.assets.debug = false

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Allow Action Cable connections from external devices (e.g., Android client)
  config.action_cable.disable_request_forgery_protection = true
  # Allow all origins in development for device connections
  config.action_cable.allowed_request_origins = [/.*/]

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Optional: Enable SSL in development for testing
  # Uncomment to test SSL locally (requires certificates)
  # config.force_ssl = true
  # config.ssl_options = { redirect: { status: 302 } }
end
