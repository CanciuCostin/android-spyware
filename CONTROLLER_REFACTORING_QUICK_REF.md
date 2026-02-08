# Controller Refactoring Quick Reference

## Quick Start

### 1. Include Concerns in Controller

```ruby
class MyController < ApplicationController
  include ErrorHandler        # Automatic exception handling
  include ResponseFormatter   # Consistent JSON responses
end
```

### 2. Create a Service Object

```ruby
class MyService < ApplicationService
  def initialize(resource, params)
    @resource = resource
    @params = params
  end
  
  def call
    # Your business logic here
    Result.success(data)
  rescue => e
    Rails.logger.error("Error: #{e.message}")
    Result.failure(e.message)
  end
end
```

### 3. Use Service in Controller

```ruby
def my_action
  result = MyService.call(resource, params)
  
  if result.success?
    render_success(result.value, message: 'Success!')
  else
    render_error(result.error)
  end
end
```

## Available Components

### Service Objects

| Service | Purpose | Usage |
|---------|---------|-------|
| `DeviceCommandService` | Send commands to devices | `DeviceCommandService.call(device, 'screenshot', {quality: 'high'})` |
| `FileUploadService` | Handle chunked uploads | `FileUploadService.call(device, upload_params)` |
| `FileFinalizationService` | Finalize uploads | `FileFinalizationService.call(upload_id, filename)` |

### Result Object

```ruby
# Success
result = Result.success({data: 'value'})
result.success?  # => true
result.value     # => {data: 'value'}

# Failure
result = Result.failure('Error message')
result.failure?  # => true
result.error     # => 'Error message'
```

### Response Methods

| Method | Status | Usage |
|--------|--------|-------|
| `render_success` | 200 OK | `render_success(data)` |
| `render_created` | 201 Created | `render_created(resource)` |
| `render_accepted` | 202 Accepted | `render_accepted(data)` |
| `render_error` | 400 Bad Request | `render_error('message')` |
| `render_not_found` | 404 Not Found | `render_not_found()` |
| `render_unauthorized` | 401 Unauthorized | `render_unauthorized()` |
| `render_forbidden` | 403 Forbidden | `render_forbidden()` |

### Serializers

```ruby
# Use in controller
render_success(device, serializer: DeviceSerializer)

# With includes
render_success(device, 
  serializer: DeviceSerializer,
  include: [:statistics, :locations]
)
```

## Common Patterns

### Before Action Pattern

```ruby
before_action :set_resource, only: [:show, :update, :destroy]

private

def set_resource
  @resource = Resource.find(params[:id])
end
```

### Strong Parameters

```ruby
private

def resource_params
  params.require(:resource).permit(:name, :description, :status)
end
```

### Service Object with Validation

```ruby
class MyService < ApplicationService
  def call
    validate!
    perform_action
    Result.success(@result)
  rescue ArgumentError => e
    Result.failure(e.message)
  end
  
  private
  
  def validate!
    raise ArgumentError, "Invalid" unless @resource.valid?
  end
  
  def perform_action
    # Business logic
  end
end
```

## Response Examples

### Success Response

```json
{
  "status": "success",
  "data": {
    "id": 1,
    "name": "Device 1"
  },
  "message": "Operation completed"
}
```

### Error Response

```json
{
  "status": "error",
  "error": {
    "message": "Device not found",
    "code": "NOT_FOUND"
  }
}
```

## Error Handling

### Automatic Handling (via ErrorHandler concern)

- `ActiveRecord::RecordNotFound` → 404
- `ActiveRecord::RecordInvalid` → 422
- `ActionController::ParameterMissing` → 400
- `ArgumentError` → 400
- `SecurityError` → 403
- `StandardError` → 500

### Custom Error Handling

```ruby
rescue_from MyCustomError, with: :handle_custom_error

private

def handle_custom_error(exception)
  render_error(exception.message, status: :unprocessable_entity)
end
```

## Cheat Sheet

### Thin Controller Template

```ruby
class ResourcesController < ApplicationController
  include ErrorHandler
  include ResponseFormatter
  
  before_action :set_resource, only: [:show, :update]
  
  def index
    resources = Resource.all
    render_success(resources, serializer: ResourceSerializer)
  end
  
  def show
    render_success(@resource, serializer: ResourceSerializer)
  end
  
  def create
    result = CreateResourceService.call(resource_params)
    
    if result.success?
      render_created(result.value, message: 'Created')
    else
      render_error(result.error)
    end
  end
  
  def update
    result = UpdateResourceService.call(@resource, resource_params)
    
    if result.success?
      render_success(result.value, message: 'Updated')
    else
      render_error(result.error)
    end
  end
  
  private
  
  def set_resource
    @resource = Resource.find(params[:id])
  end
  
  def resource_params
    params.require(:resource).permit(:name, :status)
  end
end
```

### Service Object Template

```ruby
class MyActionService < ApplicationService
  def initialize(resource, params = {})
    @resource = resource
    @params = params
  end
  
  def call
    validate!
    process
    Result.success(@result)
  rescue StandardError => e
    cleanup
    Rails.logger.error("#{self.class.name}: #{e.message}")
    Result.failure(e.message)
  end
  
  private
  
  def validate!
    raise ArgumentError, "Invalid resource" unless @resource.present?
  end
  
  def process
    # Main business logic
    @result = perform_operation
  end
  
  def perform_operation
    # Actual work here
  end
  
  def cleanup
    # Rollback or cleanup on error
  end
end
```

## Testing

### Service Test

```ruby
RSpec.describe MyService do
  describe '#call' do
    it 'returns success' do
      result = described_class.call(resource, params)
      expect(result).to be_success
    end
    
    it 'returns failure on error' do
      result = described_class.call(nil, params)
      expect(result).to be_failure
    end
  end
end
```

### Controller Test

```ruby
RSpec.describe MyController do
  describe 'POST #create' do
    it 'returns success response' do
      post :create, params: { resource: attributes }
      
      expect(response).to have_http_status(:created)
      expect(json['status']).to eq('success')
    end
  end
end
```

## Migration Checklist

- [ ] Identify business logic in controller
- [ ] Create service object
- [ ] Extract logic to service
- [ ] Include ErrorHandler concern
- [ ] Include ResponseFormatter concern
- [ ] Replace manual error handling
- [ ] Standardize JSON responses
- [ ] Create serializer if needed
- [ ] Update tests
- [ ] Document changes

## Common Mistakes to Avoid

❌ **Don't**: Put business logic in controllers
✅ **Do**: Extract to service objects

❌ **Don't**: Return inconsistent JSON formats
✅ **Do**: Use ResponseFormatter methods

❌ **Don't**: Manually handle every exception
✅ **Do**: Use ErrorHandler concern

❌ **Don't**: Return raw model attributes
✅ **Do**: Use serializers for complex data

❌ **Don't**: Mix validation and business logic
✅ **Do**: Validate first, then process

❌ **Don't**: Ignore error logging
✅ **Do**: Log errors with context

## Resources

- Full Guide: `CONTROLLER_REFACTORING_GUIDE.md`
- Service Objects: `app/services/`
- Concerns: `app/controllers/concerns/`
- Serializers: `app/serializers/`
- Examples: `app/controllers/api/devices_controller.rb`
