# Android Spyware - Tracing & Observability Guide

## Overview

This guide describes the comprehensive tracing and observability infrastructure added to the android-spyware project using **OpenTelemetry** and **Jaeger**.

### What is Tracing?

Distributed tracing tracks requests as they flow through your system, showing:

- **Request flow** through multiple services (Rails → Metasploit RPC → ADB)
- **Performance bottlenecks** (how long each operation takes)
- **Error tracking** (where failures occur and why)
- **Dependencies** (which services call which other services)

## Architecture

### Components

1. **OpenTelemetry SDK** (`opentelemetry-sdk`) - Core tracing library
2. **Jaeger Exporter** (`opentelemetry-exporter-jaeger`) - Sends traces to Jaeger
3. **Jaeger Collector** (Docker container) - Collects and stores traces
4. **Custom Instrumentation** (lib/spyware_tracing.rb) - MSF-specific tracing

### Data Flow

```
Rails Application
    ↓
SpywareTracing (custom instrumentation)
    ↓
OpenTelemetry SDK
    ↓
Jaeger UDP Agent (localhost:6831)
    ↓
Jaeger Collector (jaeger-collector:6831)
    ↓
Jaeger Storage & UI (localhost:16686)
```

## Setup

### 1. Install Dependencies

Gems have been added to `Gemfile`:

```ruby
gem "opentelemetry-api", "~> 1.0"
gem "opentelemetry-sdk", "~> 1.0"
gem "opentelemetry-exporter-jaeger", "~> 0.21"
gem "opentelemetry-instrumentation-rack", "~> 0.20"
gem "opentelemetry-instrumentation-rails", "~> 0.26"
gem "opentelemetry-instrumentation-http_client", "~> 0.21"
```

Install gems:

```bash
bundle install
```

### 2. Start with Tracing Enabled

#### Option A: Docker Compose with Jaeger

```bash
cd docker
docker-compose -f docker-compose.yml -f docker-compose.tracing.yml up -d
```

This will:

- Start all regular services (rails-app, db, metasploit)
- Start **Jaeger collector** on port 6831 (UDP)
- Configure Rails to send traces to Jaeger

#### Option B: Environment Configuration

```bash
# Load tracing environment
export $(cat .env.tracing | xargs)

# Start Rails
rails s
```

### 3. Access Jaeger UI

Navigate to **<http://localhost:16686>** to view:

- Service list (android-spyware, metasploit, etc.)
- Traces of all operations
- Performance metrics
- Error analysis

## Usage

### Automatic Tracing

The following operations are **automatically traced**:

#### Rails HTTP Requests

```
GET /admin → Trace: "controller.admin.index"
  - http.method: GET
  - http.status_code: 200
  - duration.ms: 125.5
  - error: false
```

#### Metasploit RPC Operations

```
MSF Login → Trace: "rpc.call.login"
  - rpc.method: login
  - rpc.service: Msf::RPC::Client
  - login.success: true
  - login.user: cool
```

#### Session Commands

```
Send Shell Command → Trace: "session.meterpreter_command"
  - session.id: 1
  - command: "id"
  - command.length: 2
  - command.status: success
  - command.output.lines: 5
```

#### ADB Operations

```
ADB Device List → Trace: "adb.operation"
  - adb.command: "devices -l"
  - adb.service: Android Debug Bridge
  - adb.command.status: success
  - adb.output.size: 256
```

### Custom Tracing in Code

#### Trace MSF Operations

```ruby
SpywareTracing.trace_msf_operation('payload_generation', {
  name: 'TestPayload',
  destination_ip: '192.168.1.100',
  destination_port: 4444
}) do |span|
  # Your MSF operation here
  result = generate_apk('TestPayload', '192.168.1.100', 4444)
  
  # Log custom attributes
  span.set_attribute('apk.size', result.size)
  span.set_attribute('generation.success', true)
  
  result
end
```

#### Trace RPC Calls

```ruby
SpywareTracing.trace_rpc_call('session.shell_command', { command: 'whoami' }) do |span|
  result = rpc.call('session.shell_command', session_id, 'whoami')
  span.set_attribute('command.output', result)
  result
end
```

#### Track Errors

```ruby
begin
  dangerous_operation()
rescue => e
  SpywareTracing.record_error(span, e, 'operation_name')
  # Trace will show:
  # - error: true
  # - error.kind: StandardError
  # - error.message: error details
  # - error.operation: operation_name
end
```

## Tracing Spans

### Span Hierarchy

```
controller.apk_payloads.create (entry point)
├── apk.generation
│   ├── rpc.call.module.execute
│   │   └── job.id: 1
│   └── rpc.call.session.list
│       ├── session.id: 1
│       ├── rpc.call.session.meterpreter_write
│       └── rpc.call.session.meterpreter_read
└── apk.file_creation
    └── file.write
```

### Key Span Types

| Span Name | Purpose | Attributes |
|-----------|---------|-----------|
| `rpc.call.*` | Metasploit RPC calls | method, params, result type |
| `session.meterpreter_command` | Remote shell commands | session.id, command, output |
| `adb.operation` | ADB commands | command, output.size, status |
| `apk.generation` | APK payload creation | name, ip, port, size |
| `controller.*` | HTTP requests | method, status, duration |

## Viewing Traces

### Jaeger UI Features

1. **Service Selection**: View traces by service
   - Select: `android-spyware`
   - See all traces from this service

2. **Operation Filter**: Filter by operation type
   - `controller.apk_payloads.create`
   - `rpc.call.*`
   - `adb.operation`

3. **Trace Detail View**:
   - Timeline of all spans
   - Duration of each operation
   - Span attributes and tags
   - Error details with stack traces

4. **Search**: Filter by:
   - Service name
   - Operation name
   - Tag values (e.g., `error=true`)
   - Duration ranges

### Query Examples

Find all failed MSF operations:

```
Tags: error=true AND rpc.service=Msf::RPC::Client
```

Find slow ADB commands:

```
Service: android-spyware
Operation: adb.operation
Min Duration: 1000ms
```

Find session commands for specific device:

```
Tags: session.id=1
```

## Performance Analysis

### Identifying Bottlenecks

1. **Slow HTTP Requests**: Check `duration.ms` > 5000ms

   ```
   → Usually indicates MSF/ADB operation delay
   ```

2. **Failed RPC Calls**: Check spans with `error=true`

   ```
   → Check error.message for MSF-specific errors
   ```

3. **Stuck Sessions**: Long-running `session.meterpreter_command` spans

   ```
   → May indicate unresponsive device or network issues
   ```

### Metrics to Monitor

- **P95/P99 latency** for each operation
- **Error rates** by operation type
- **Request throughput** (traces per second)
- **Session count** active at any time

## Integration with Existing Code

### Modify Application Controller

Add instrumented method calls to existing MSF operations:

```ruby
# Before (application_controller.rb)
def start_msf_process(command)
  # existing code...
end

# After
def start_msf_process(command)
  start_msf_process_traced(command)
end
```

Include mixin:

```ruby
class ApplicationController < ActionController::Base
  include MsfInstrumentation::ApplicationControllerMixin
  # ...
end
```

## Troubleshooting

### No Traces Appearing

**Check 1**: Jaeger container running?

```bash
docker ps | grep jaeger
```

**Check 2**: Rails environment variables set?

```bash
echo $JAEGER_HOST
echo $JAEGER_PORT
```

**Check 3**: Check Rails logs for initialization:

```bash
docker logs docker-rails-app-1 | grep OpenTelemetry
```

### High Latency / Missing Spans

- **Sampler setting**: Check `.env.tracing` for `JAEGER_SAMPLER_PARAM=1` (100% sampling)
- **Network issues**: Verify `JAEGER_HOST` is reachable from Rails container
- **UDP port blocked**: Ensure port 6831 UDP is accessible

### Memory Usage

OpenTelemetry is lightweight, but high trace volume can increase memory:

- Reduce sampling: `JAEGER_SAMPLER_PARAM=0.1` (10% sampling)
- Enable compression: Handled automatically by Jaeger exporter

## Environment Variables

Create `.env.local` to override defaults:

```bash
# Override Jaeger location
JAEGER_HOST=jaeger-collector
JAEGER_PORT=6831

# Control sampling
JAEGER_SAMPLER_TYPE=const
JAEGER_SAMPLER_PARAM=1  # 1 = 100%, 0.1 = 10%

# Service identification
OTEL_SERVICE_NAME=android-spyware-dev
OTEL_SERVICE_VERSION=1.0.0

# Logging
OTEL_LOG_LEVEL=INFO  # DEBUG for verbose output
```

## Production Considerations

1. **Sampling**: Use adaptive sampling instead of 100%

   ```
   JAEGER_SAMPLER_TYPE=remote
   JAEGER_SAMPLER_PARAM=0.1
   ```

2. **Storage**: Configure Jaeger backend
   - Default: In-memory (data lost on restart)
   - Production: Elasticsearch, Cassandra, or Badger

3. **Retention**: Set trace retention policy

   ```
   COLLECTOR_OTLP_ENABLED=true
   BADGER_EPHEMERAL=false
   ```

4. **Security**:
   - Secure Jaeger UI with authentication
   - Use TLS for gRPC collector
   - Sanitize sensitive data in spans

## See Also

- [OpenTelemetry Documentation](https://opentelemetry.io/)
- [Jaeger Documentation](https://www.jaegertracing.io/)
- [Ruby OpenTelemetry SDK](https://github.com/open-telemetry/opentelemetry-ruby)
- [spyware_tracing.rb](../../lib/spyware_tracing.rb) - Custom instrumentation
- [msf_instrumentation.rb](../../lib/msf_instrumentation.rb) - MSF-specific tracing
