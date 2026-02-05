unless Rails.env.test?
  token_present = ENV['DEVICE_AUTH_TOKEN'].present? || File.exist?(Rails.root.join('config/device_secret.token'))

  if !token_present
    Rails.logger.fatal('[Startup] DEVICE_AUTH_TOKEN or config/device_secret.token is missing. API requests will fail.')
    raise 'DEVICE_AUTH_TOKEN not configured'
  end
end
