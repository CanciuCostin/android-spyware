source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Compatible with Ruby 3.1+
# Remove restrictive Ruby version requirement
gem "mimemagic", github: "mimemagicrb/mimemagic", ref: "01f92d86d15d85cfd0f20dabd025dcbd36a8a60f"
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 6.0"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
gem "ffi"
gem "concurrent-ruby"
gem "logger", "~> 1.5.0"  # Must match Ruby 3.1 default; >= 1.6 breaks Rails 6.1
# Use Puma as the app server (Docker only, WEBrick for Windows dev)
gem "puma", ">= 5.0", install_if: -> { !Gem.win_platform? }
gem "webrick", install_if: -> { Gem.win_platform? }
# Use SCSS for stylesheets
gem "sass-rails", ">= 6"
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.7"
gem "graphql"
# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"
# Connection pooling for Redis
gem "connection_pool", "~> 2.4"
# Background job processing (Sidekiq)
# gem "sidekiq", "~> 7.0"
# gem "sidekiq-scheduler", "~> 5.0"  # Cron-like recurring jobs
  # Use Active Model has_secure_password
  gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching (skip on Windows if msgpack fails)
gem "bootsnap", ">= 1.4.2", require: false, install_if: -> { !Gem.win_platform? }

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "byebug", platforms: [:mri, :mingw, :x64_mingw]
  gem "factory_bot_rails"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 3.3.0"
end

group :test do
  gem "simplecov", require: false
  # Adds support for Capybara system testing and selenium driver
  gem "capybara", ">= 2.15"
  gem "selenium-webdriver"
  # Easy installation and use of web drivers to run system tests with browsers
  gem "webdrivers"
  gem "webmock"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem "activeadmin"

# Plus integrations with:
gem "devise"

gem "bootstrap", "~> 4.3.1"

gem "jquery-rails"

gem "active_admin_flat_skin", github: "ayann/active_admin_flat_skin"

gem "webpacker", ">= 4.x"

gem "responders"

gem "msfrpc-client", install_if: -> { !Gem.win_platform? }

gem "minitar"

gem "sqlite3"

# Tracing & Observability
gem "opentelemetry-api"
gem "opentelemetry-sdk"
# gem "opentelemetry-exporter-jaeger" # Requires thrift native ext — disabled on Windows
gem "opentelemetry-instrumentation-rack"
gem "opentelemetry-instrumentation-rails"
gem "opentelemetry-instrumentation-http_client"

gem 'rack-attack'

# Request-local storage for audit trail
gem 'request_store'

# Pagination for audit logs
gem 'kaminari'

# Cron job management
gem 'whenever', require: false

group :development, :test do
  gem 'rspec-rails', '~> 5.0'
end
