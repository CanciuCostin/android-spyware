# frozen_string_literal: true

class DeviceIdValidator
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  HEX_PATTERN = /\A[0-9a-fA-F]+\z/
  ALPHANUMERIC_PATTERN = /\A[a-zA-Z0-9._:\-]+\z/
  MAX_LENGTH = 128

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(device_id)
    new.validate(device_id)
  end

  def validate(device_id)
    return failure("Device ID is required") if device_id.nil? || device_id.to_s.strip.empty?

    sanitized = device_id.to_s.strip

    return failure("Device ID too long (max #{MAX_LENGTH})") if sanitized.length > MAX_LENGTH
    return failure("Device ID contains invalid characters") unless sanitized.match?(ALPHANUMERIC_PATTERN)

    success(sanitized)
  end

  def self.uuid?(value)
    value.to_s.match?(UUID_PATTERN)
  end

  def self.hex?(value)
    value.to_s.match?(HEX_PATTERN)
  end

  def self.sanitize(device_id)
    result = validate(device_id)
    result.valid? ? result.value : nil
  end

  private

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
