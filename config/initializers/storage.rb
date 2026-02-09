Rails.application.config.x.storage = ActiveSupport::OrderedOptions.new

# Storage backend: 'local' or 's3'
Rails.application.config.x.storage.backend = ENV.fetch('STORAGE_BACKEND', 'local')

# Local storage settings
Rails.application.config.x.storage.local_root = Rails.root.join('files', 'uploads')

# S3 settings
Rails.application.config.x.storage.s3_bucket = ENV['S3_BUCKET']
Rails.application.config.x.storage.s3_region = ENV.fetch('S3_REGION', 'us-east-1')
Rails.application.config.x.storage.s3_access_key_id = ENV['S3_ACCESS_KEY_ID']
Rails.application.config.x.storage.s3_secret_access_key = ENV['S3_SECRET_ACCESS_KEY']
Rails.application.config.x.storage.s3_endpoint = ENV['S3_ENDPOINT'] # For MinIO / custom S3

# Upload settings
Rails.application.config.x.storage.max_file_size = (ENV.fetch('MAX_FILE_SIZE_MB', '500').to_i).megabytes
Rails.application.config.x.storage.chunk_size = (ENV.fetch('UPLOAD_CHUNK_SIZE_MB', '5').to_i).megabytes
Rails.application.config.x.storage.multipart_threshold = 100.megabytes

# Retention and cleanup
Rails.application.config.x.storage.retention_days = ENV.fetch('FILE_RETENTION_DAYS', '30').to_i
Rails.application.config.x.storage.stale_upload_hours = ENV.fetch('STALE_UPLOAD_HOURS', '24').to_i
Rails.application.config.x.storage.disk_usage_alert_percent = ENV.fetch('DISK_USAGE_ALERT_PERCENT', '80').to_i

# Signed URL expiry (seconds)
Rails.application.config.x.storage.signed_url_expiry = ENV.fetch('SIGNED_URL_EXPIRY', '3600').to_i
