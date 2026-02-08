# frozen_string_literal: true

class CoordinateValidator
  LATITUDE_RANGE = (-90.0..90.0)
  LONGITUDE_RANGE = (-180.0..180.0)

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(lat, lng)
    new.validate(lat, lng)
  end

  def self.validate_latitude(lat)
    new.validate_latitude(lat)
  end

  def self.validate_longitude(lng)
    new.validate_longitude(lng)
  end

  def validate(lat, lng)
    lat_result = validate_latitude(lat)
    return lat_result unless lat_result.valid?

    lng_result = validate_longitude(lng)
    return lng_result unless lng_result.valid?

    success(latitude: lat_result.value, longitude: lng_result.value)
  end

  def validate_latitude(lat)
    return failure("Latitude is required") if lat.nil?

    value = parse_coordinate(lat)
    return failure("Latitude must be a number") if value.nil?
    return failure("Latitude must be between -90 and 90") unless LATITUDE_RANGE.cover?(value)

    success(value)
  end

  def validate_longitude(lng)
    return failure("Longitude is required") if lng.nil?

    value = parse_coordinate(lng)
    return failure("Longitude must be a number") if value.nil?
    return failure("Longitude must be between -180 and 180") unless LONGITUDE_RANGE.cover?(value)

    success(value)
  end

  private

  def parse_coordinate(value)
    return value.to_f if value.is_a?(Numeric)

    str = value.to_s.strip
    return nil unless str.match?(/\A-?\d+(\.\d+)?\z/)

    str.to_f
  end

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
