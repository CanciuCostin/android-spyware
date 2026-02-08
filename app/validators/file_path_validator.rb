# frozen_string_literal: true

class FilePathValidator
  MAX_PATH_LENGTH = 1024
  TRAVERSAL_PATTERNS = [
    '..', '%2e%2e', '%252e%252e', '..%c0%af', '..%c1%9c',
    '\\.\\', '%5c', '%2f'
  ].freeze
  NULL_BYTES = ["\x00", '%00'].freeze
  DANGEROUS_CHARS = /[;&|`$><\n\r]/

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(path, base_dir: nil)
    new.validate(path, base_dir: base_dir)
  end

  def self.sanitize(path)
    new.sanitize(path)
  end

  def validate(path, base_dir: nil)
    return failure("Path is required") if path.nil? || path.to_s.strip.empty?

    cleaned = sanitize(path)
    return failure("Path is empty after sanitization") if cleaned.empty?
    return failure("Path too long (max #{MAX_PATH_LENGTH})") if cleaned.length > MAX_PATH_LENGTH
    return failure("Path contains traversal sequences") if contains_traversal?(cleaned)
    return failure("Path contains dangerous characters") if cleaned.match?(DANGEROUS_CHARS)

    if base_dir
      expanded = File.expand_path(cleaned, base_dir)
      base_expanded = File.expand_path(base_dir)
      unless expanded.start_with?(base_expanded)
        return failure("Path escapes base directory")
      end
    end

    success(cleaned)
  end

  def sanitize(path)
    cleaned = path.to_s.strip

    NULL_BYTES.each { |nb| cleaned = cleaned.gsub(nb, '') }
    cleaned = cleaned.gsub("\x00", '')

    # Normalize separators
    cleaned = cleaned.tr('\\', '/')

    # Remove consecutive separators
    cleaned = cleaned.gsub(%r{/+}, '/')

    # Remove leading/trailing whitespace from each component
    cleaned = cleaned.split('/').map(&:strip).reject(&:empty?).join('/')

    cleaned
  end

  private

  def contains_traversal?(path)
    normalized = path.downcase
    return true if normalized.include?('..')

    TRAVERSAL_PATTERNS.any? { |pattern| normalized.include?(pattern.downcase) }
  end

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
