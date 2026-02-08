# Controller Refactoring Guide

## Overview

This guide documents the controller refactoring initiative to extract business logic into service objects, implement the thin controller pattern, standardize error handling, and ensure consistent response formats throughout the EagleSpy application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Service Objects](#service-objects)
3. [Error Handling](#error-handling)
4. [Response Formatting](#response-formatting)
5. [Serializers](#serializers)
6. [Migration Guide](#migration-guide)
7. [Best Practices](#best-practices)
8. [Examples](#examples)

## Architecture Overview

### Thin Controller Pattern

Controllers should be thin and focus solely on:
- Request handling and parameter extraction
- Calling service objects
- Rendering responses
- Authentication/authorization

Business logic, data processing, and complex operations should be extracted into service objects.

### Layered Architecture

```
Request → Controller → Service Object → Models → Database
                ↓
          Response Formatter
```

## Service Objects

### Base Service Class

All service objects inherit from `ApplicationService`:

```ruby
class ApplicationService
  def self.call(*args, &block)
    new(*args, &block).call
  end
end
```

### Result Object

Services return a `Result` object to indicate success or failure:

```ruby
class Result
  attr_reader :value, :error
  
  def self.success(value)
    new(success: true, value: value)
  end
  
  def self.failure(error)
    new(success: false, error: error)
  end
  
  def success?
    @success
  end
  
  def failure?
    !@success
  end
end
```

### Creating a Service Object

1. **Inherit from ApplicationService**
2. **Define initialize method** with required parameters
3. **Implement call method** with business logic
4. **Return Result objects** for success/failure
5. **Handle exceptions** and log errors

Example:

```ruby
class DeviceCommandService < ApplicationService
  def initialize(device, command_type, params = {})
    @device = device
    @command_type = command_type
    @params = params
  end
  
  def call
    validate_device!
    validate_command!
    
    pending_command = create_pending_command
    broadcast_command(pending_command)
    
    Result.success(pending_command)
  rescue => e
    Rails.logger.error("Command failed: #{e.message}")
    Result.failure(e.message)
  end
  
  private
  
  def validate_device!
    raise ArgumentError, "Device not connected" unless @device.connected?
  end
  
  # ... more private methods
end
```

### Available Service Objects

#### DeviceCommandService

**Purpose**: Handle device command operations

**Location**: `app/services/device_command_service.rb`

**Usage**:
```ruby
result = DeviceCommandService.call(device, 'take_screenshot', {quality: 'high'})

if result.success?
  # Handle success
  command = result.value
else
  # Handle error
  error = result.error
end
```

#### FileUploadService

**Purpose**: Handle chunked file uploads

**Location**: `app/services/file_upload_service.rb`

**Usage**:
```ruby
result = FileUploadService.call(device, {
  upload_id: '123-456',
  chunk_index: 0,
  total_chunks: 10,
  file: file_chunk,
  filename: 'document.pdf'
})
```

#### FileFinalizationService

**Purpose**: Finalize chunked uploads after all chunks received

**Location**: `app/services/file_finalization_service.rb`

**Usage**:
```ruby
result = FileFinalizationService.call(upload_id, filename)

if result.success?
  file_path = result.value[:path]
  file_size = result.value[:size]
end
```

## Error Handling

### ErrorHandler Concern

Include in controllers to standardize error handling:

```ruby
class MyController < ApplicationController
  include ErrorHandler
  # ...
end
```

### Handled Exceptions

- `StandardError` → 500 Internal Server Error
- `ActiveRecord::RecordNotFound` → 404 Not Found
- `ActiveRecord::RecordInvalid` → 422 Unprocessable Entity
- `ActionController::ParameterMissing` → 400 Bad Request
- `ArgumentError` → 400 Bad Request
- `SecurityError` → 403 Forbidden

### Custom Error Handling

Override specific handlers in your controller:

```ruby
class MyController < ApplicationController
  include ErrorHandler
  
  rescue_from MyCustomError, with: :handle_custom_error
  
  private
  
  def handle_custom_error(exception)
    render_error(exception.message, status: :unprocessable_entity)
  end
end
```

## Response Formatting

### ResponseFormatter Concern

Provides consistent JSON response formats:

```ruby
class MyController < ApplicationController
  include ResponseFormatter
  # ...
end
```

### Available Methods

#### Success Responses

```ruby
# Standard success (200 OK)
render_success(data, message: 'Operation successful')

# Created (201 Created)
render_created(data, message: 'Resource created')

# Accepted (202 Accepted)
render_accepted(data, message: 'Request accepted for processing')
```

#### Error Responses

```ruby
# Bad request (400)
render_error('Invalid parameters', status: :bad_request)

# Not found (404)
render_not_found('Resource not found')

# Unauthorized (401)
render_unauthorized('Authentication required')

# Forbidden (403)
render_forbidden('Access denied')
```

### Response Format

Success:
```json
{
  "status": "success",
  "data": { ... },
  "message": "Operation successful"
}
```

Error:
```json
{
  "status": "error",
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "details": "Additional details (dev only)"
  }
}
```

## Serializers

### Creating a Serializer

```ruby
class DeviceSerializer
  def initialize(device, options = {})
    @device = device
    @options = options
  end
  
  def as_json
    {
      id: @device.id,
      name: @device.name,
      # ... more fields
    }
  end
end
```

### Using Serializers

```ruby
# Single object
render_success(device, serializer: DeviceSerializer)

# Collection
render_success(devices, serializer: DeviceSerializer)

# With includes
render_success(device, 
  serializer: DeviceSerializer, 
  include: [:locations, :statistics]
)
```

### Available Serializers

#### DeviceSerializer

**Location**: `app/serializers/device_serializer.rb`

**Fields**: id, device_id, name, model, manufacturer, os_version, last_seen

**Includes**: 
- `:recent_locations` - Last 10 geo locations
- `:statistics` - Aggregated statistics
- `:pending_commands` - Current pending commands

## Migration Guide

### Step-by-Step Refactoring

#### 1. Identify Business Logic

Look for:
- Complex data processing
- Multiple model operations
- External API calls
- File operations
- Command broadcasting

#### 2. Extract to Service Object

**Before**:
```ruby
class DevicesController < ApplicationController
  def send_command
    device = Device.find(params[:id])
    
    # Validation
    return render json: {error: 'Invalid'} unless device.connected?
    
    # Business logic
    command = device.pending_commands.create!(...)
    ActionCable.server.broadcast(...)
    
    render json: {success: true}
  rescue => e
    render json: {error: e.message}
  end
end
```

**After**:
```ruby
class DevicesController < ApplicationController
  include ErrorHandler
  include ResponseFormatter
  
  def send_command
    device = Device.find(params[:id])
    result = DeviceCommandService.call(device, params[:command])
    
    if result.success?
      render_success(result.value, message: 'Command sent')
    else
      render_error(result.error)
    end
  end
end
```

#### 3. Add Error Handling

Include the `ErrorHandler` concern and remove manual error handling:

```ruby
class MyController < ApplicationController
  include ErrorHandler
  # Automatic error handling for common exceptions
end
```

#### 4. Standardize Responses

Replace manual JSON rendering with response formatter methods:

```ruby
# Before
render json: {success: true, data: @device}

# After
render_success(@device, serializer: DeviceSerializer)
```

#### 5. Add Serializers

Create serializers for complex objects:

```ruby
class DeviceSerializer
  def initialize(device, options = {})
    @device = device
    @options = options
  end
  
  def as_json
    # Return hash of attributes
  end
end
```

### Backward Compatibility

When refactoring existing controllers:

1. **Keep old methods** initially for backward compatibility
2. **Add new endpoints** with refactored code
3. **Deprecate old endpoints** with warnings
4. **Remove old code** after migration period

Example:

```ruby
# Legacy method (deprecated)
def old_send_command
  # Old implementation
  Rails.logger.warn "[DEPRECATED] Use send_command instead"
  send_command
end

# New method
def send_command
  # Refactored implementation
end
```

## Best Practices

### Service Objects

✅ **Do**:
- Keep services focused on a single responsibility
- Use descriptive names (verb + noun: `CreateUser`, `SendCommand`)
- Return Result objects consistently
- Log errors with context
- Write comprehensive tests

❌ **Don't**:
- Mix multiple responsibilities in one service
- Return different types (use Result pattern)
- Swallow exceptions silently
- Make services too generic

### Controllers

✅ **Do**:
- Keep controllers thin (< 10 lines per action)
- Use before_action for common setup
- Include concerns for shared behavior
- Use strong parameters
- Delegate to service objects

❌ **Don't**:
- Put business logic in controllers
- Manually handle common exceptions
- Return inconsistent response formats
- Skip parameter validation

### Error Handling

✅ **Do**:
- Log all errors with context
- Return appropriate HTTP status codes
- Provide helpful error messages
- Hide sensitive details in production

❌ **Don't**:
- Expose stack traces in production
- Use generic error messages
- Ignore exceptions
- Return wrong status codes

### Response Formatting

✅ **Do**:
- Use consistent JSON structure
- Include status field
- Provide meaningful messages
- Use serializers for complex data

❌ **Don't**:
- Mix response formats
- Return raw model attributes
- Include unnecessary data
- Skip serialization

## Examples

### Complete Controller Example

```ruby
class DevicesController < ApplicationController
  include ErrorHandler
  include ResponseFormatter
  
  before_action :authenticate_user!
  before_action :set_device, only: [:show, :send_command]
  
  # GET /devices
  def index
    devices = Device.accessible_by(current_user)
                    .page(params[:page])
    
    render_success(devices, 
      serializer: DeviceSerializer,
      message: "Found #{devices.total_count} devices"
    )
  end
  
  # GET /devices/:id
  def show
    render_success(@device,
      serializer: DeviceSerializer,
      include: [:statistics, :recent_locations]
    )
  end
  
  # POST /devices/:id/commands
  def send_command
    result = DeviceCommandService.call(
      @device,
      params[:command],
      command_params
    )
    
    if result.success?
      render_accepted(result.value, 
        message: 'Command queued for execution'
      )
    else
      render_error(result.error)
    end
  end
  
  private
  
  def set_device
    @device = Device.find(params[:id])
  end
  
  def command_params
    params.permit(:duration, :quality, :filename)
  end
end
```

### Complete Service Example

```ruby
class DeviceCommandService < ApplicationService
  def initialize(device, command, params = {})
    @device = device
    @command = command
    @params = params
  end
  
  def call
    validate!
    execute_command
    Result.success(@command_record)
  rescue StandardError => e
    cleanup_on_error
    Rails.logger.error("Command failed: #{e.message}")
    Result.failure(e.message)
  end
  
  private
  
  def validate!
    raise ArgumentError, "Device offline" unless @device.online?
    raise ArgumentError, "Invalid command" unless valid_command?
  end
  
  def execute_command
    @command_record = @device.pending_commands.create!(
      command: @command,
      params: @params,
      request_id: SecureRandom.uuid
    )
    
    broadcast_to_device
  end
  
  def broadcast_to_device
    ActionCable.server.broadcast(
      "commands_#{@device.id}",
      command_data
    )
  end
  
  def command_data
    {
      type: @command,
      request_id: @command_record.request_id,
      params: @params
    }
  end
  
  def valid_command?
    %w[screenshot location camera].include?(@command)
  end
  
  def cleanup_on_error
    @command_record&.destroy
  end
end
```

## Testing

### Service Object Tests

```ruby
require 'rails_helper'

RSpec.describe DeviceCommandService do
  describe '#call' do
    let(:device) { create(:device, online: true) }
    
    context 'with valid parameters' do
      it 'returns success result' do
        result = described_class.call(device, 'screenshot')
        
        expect(result).to be_success
        expect(result.value).to be_a(PendingCommand)
      end
    end
    
    context 'with offline device' do
      let(:device) { create(:device, online: false) }
      
      it 'returns failure result' do
        result = described_class.call(device, 'screenshot')
        
        expect(result).to be_failure
        expect(result.error).to include('offline')
      end
    end
  end
end
```

### Controller Tests

```ruby
require 'rails_helper'

RSpec.describe DevicesController, type: :controller do
  describe 'POST #send_command' do
    let(:device) { create(:device) }
    
    context 'when command succeeds' do
      it 'returns success response' do
        post :send_command, params: {
          id: device.id,
          command: 'screenshot'
        }
        
        expect(response).to have_http_status(:accepted)
        expect(json_response['status']).to eq('success')
      end
    end
    
    context 'when command fails' do
      it 'returns error response' do
        allow(DeviceCommandService).to receive(:call)
          .and_return(Result.failure('Device offline'))
        
        post :send_command, params: {
          id: device.id,
          command: 'screenshot'
        }
        
        expect(response).to have_http_status(:bad_request)
        expect(json_response['status']).to eq('error')
      end
    end
  end
end
```

## Conclusion

This refactoring establishes a solid foundation for maintainable, testable, and consistent controller code. By following these patterns and guidelines, you can ensure that:

- Business logic is properly encapsulated
- Error handling is consistent and robust
- API responses follow a uniform structure
- Code is easier to test and maintain

For questions or contributions, please refer to the project documentation or contact the development team.
