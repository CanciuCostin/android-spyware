# Input Validation Guide

## Overview

EagleSpy V5 includes a centralized input validation framework that provides:

- **Type-specific validators** for device IDs, commands, file paths, uploads, coordinates, and phone numbers
- **A unified service** (`InputValidator`) that delegates to specialized validators
- **A controller concern** (`InputSanitization`) for automatic parameter sanitization
- **Rack middleware** (`InputSanitizationMiddleware`) for global request-level sanitization
- **SQL injection and XSS detection/prevention helpers**
- **Rate limiting per input type**

## Quick Start

### Using InputValidator directly

```ruby
# Validate a device ID
result = InputValidator.validate_device_id("abc-123")
if result.valid?
  device_id = result.value
else
  puts result.error
end

# Validate a command with params
result = InputValidator.validate_command('send_sms', phone_number: '+123', message_body: 'hi')

# Validate file paths (prevent traversal)
result = InputValidator.validate_file_path('docs/file.txt', base_dir: '/uploads')

# Validate coordinates
result = InputValidator.validate_coordinates(42.36, -71.06)

# Validate phone numbers
result = InputValidator.validate_phone_number('+1-555-123-4567')

# Check for SQL injection
InputValidator.contains_sql_injection?("admin' OR 1=1") # => true

# Sanitize XSS
InputValidator.sanitize_xss('<script>alert(1)</script>') # => "&lt;script&gt;..."

# Rate limiting
InputValidator.within_rate_limit?('device_id', request.ip, max_requests: 100, window: 60)
```

### Using in Controllers

Include `InputSanitization` to automatically sanitize all request parameters:

```ruby
class MyController < ApplicationController
  include InputSanitization

  def create
    # params are already sanitized (null bytes removed, unicode normalized)

    # Type coercion helpers
    page = coerce_to_integer(params[:page], default: 1)
    lat  = coerce_to_float(params[:lat])
    flag = coerce_to_boolean(params[:active], default: false)

    # Whitelist params
    safe = whitelist_params(%i[name email phone])
  end
end
```

### Using Individual Validators

```ruby
# Device ID
DeviceIdValidator.validate("device-abc")
DeviceIdValidator.uuid?("a1b2c3d4-e5f6-7890-abcd-ef1234567890") # => true
DeviceIdValidator.sanitize("device-abc") # => "device-abc" or nil

# Commands
CommandValidator.validate('get_contacts')
CommandValidator.allowed?('get_contacts') # => true

# File paths
FilePathValidator.validate('../../etc/passwd') # => invalid
FilePathValidator.sanitize('path\\to\\file')   # => "path/to/file"

# Uploads
UploadValidator.validate(upload_id: uuid, filename: 'test.apk', total_chunks: 10, chunk_index: 0)
UploadValidator.validate_upload_id(uuid)

# Coordinates
CoordinateValidator.validate(42.36, -71.06)
CoordinateValidator.validate_latitude(42.36)

# Phone numbers
PhoneNumberValidator.validate('+1-555-123-4567')
PhoneNumberValidator.sanitize('+1-555-CALL')
```

## Adding a New Validator

1. Create `app/validators/my_validator.rb`:

```ruby
# frozen_string_literal: true

class MyValidator
  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(input)
    new.validate(input)
  end

  def validate(input)
    return failure("Input is required") if input.nil?
    # ... your validation logic ...
    success(input)
  end

  private

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
```

2. Add a delegation method to `InputValidator`:

```ruby
def self.validate_my_thing(input)
  MyValidator.validate(input)
end
```

3. Add specs in `spec/validators/my_validator_spec.rb`.

## Architecture

```
app/
  validators/
    device_id_validator.rb      # UUID/hex/alphanumeric device ID validation
    command_validator.rb         # Command whitelist + param validation
    file_path_validator.rb       # Path traversal prevention
    upload_validator.rb          # File upload validation (type, size, chunks)
    coordinate_validator.rb      # Lat/lng range validation
    phone_number_validator.rb    # Phone number format validation
  services/
    input_validator.rb           # Unified facade delegating to validators
  controllers/concerns/
    input_sanitization.rb        # Auto-sanitization before_action
  middleware/
    input_sanitization_middleware.rb  # Rack-level null byte/unicode cleanup
spec/
  validators/                    # Per-validator specs
  services/
    input_validator_spec.rb      # Integration specs
```

## Middleware Stack Order

The `InputSanitizationMiddleware` runs **before** other custom middleware:

```
InputSanitizationMiddleware  ← cleans raw input first
  → AuditMiddleware          ← logs clean params
  → SecurityHeaders          ← adds response headers
  → ConsentEnforcement       ← checks consent
  → Application
```

## Security Best Practices

1. **Always validate before use**: Never use raw `params` values in SQL queries, file operations, or shell commands without validation.

2. **Use the Result pattern**: Check `result.valid?` before using `result.value`. Never assume validation passes.

3. **Prefer whitelisting**: Use `CommandValidator::ALLOWED_COMMANDS` and `UploadValidator::ALLOWED_CONTENT_TYPES` rather than blacklisting.

4. **Validate at the boundary**: Apply validation as early as possible—in the controller or middleware layer.

5. **Use base_dir for file paths**: Always pass `base_dir:` when validating file paths to prevent directory traversal:
   ```ruby
   FilePathValidator.validate(user_path, base_dir: Rails.root.join('uploads'))
   ```

6. **Rate limit sensitive inputs**: Use `InputValidator.within_rate_limit?` for endpoints that accept device IDs or upload chunks.

7. **Log suspicious inputs**: The `InputSanitization` concern automatically logs when parameters are modified during sanitization.

8. **Don't rely on client-side validation**: All validation must happen server-side. Client-side validation is for UX only.
