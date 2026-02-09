# frozen_string_literal: true

class PhoneNumberValidator
  # E.164-ish: optional +, digits, optional separators
  PHONE_PATTERN = /\A\+?[\d\s\-().]{3,20}\z/
  DIGITS_ONLY_PATTERN = /\A\d+\z/
  MIN_DIGITS = 3
  MAX_LENGTH = 20

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(number)
    new.validate(number)
  end

  def self.sanitize(number)
    new.sanitize(number)
  end

  def validate(number)
    return failure("Phone number is required") if number.nil? || number.to_s.strip.empty?

    cleaned = sanitize(number)
    digits = cleaned.gsub(/\D/, '')

    return failure("Phone number too short (min #{MIN_DIGITS} digits)") if digits.length < MIN_DIGITS
    return failure("Phone number too long (max #{MAX_LENGTH} chars)") if cleaned.length > MAX_LENGTH
    return failure("Phone number contains invalid characters") unless cleaned.match?(PHONE_PATTERN)

    success(cleaned)
  end

  def sanitize(number)
    cleaned = number.to_s.strip
    cleaned.gsub(/[^0-9+\-() ]/, '')[0, MAX_LENGTH] || ''
  end

  private

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
