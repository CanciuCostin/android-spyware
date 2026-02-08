# Background Jobs & Caching Guide

## Background Jobs (Sidekiq)

### Architecture

EagleSpy V5 uses **ActiveJob** as the job framework with **Sidekiq** as the production queue adapter. Jobs fall into four priority queues:

| Queue | Weight | Purpose |
|-------|--------|---------|
| `critical` | 6 | Security alerts, emergency commands |
| `default` | 4 | Standard command processing |
| `notifications` | 3 | Async notification delivery |
| `scheduled` | 2 | Periodic cleanup & metrics |
| `low_priority` | 1 | Data retention, archival |

### Configuration

| File | Purpose |
|------|---------|
| `config/initializers/sidekiq.rb` | Redis connection, server/client config |
| `config/sidekiq.yml` | Queue definitions, concurrency |

**Environment variables:**

```bash
REDIS_URL=redis://localhost:6379/1      # Redis instance
SIDEKIQ_CONCURRENCY=10                  # Worker threads
SIDEKIQ_CLIENT_POOL_SIZE=5              # Client connection pool
```

### Starting Sidekiq

```bash
# Development
bundle exec sidekiq -C config/sidekiq.yml

# Docker (add to docker-compose.yml)
sidekiq:
  build: .
  command: bundle exec sidekiq -C config/sidekiq.yml
  depends_on: [redis, db]
  env_file: .env
```

### Jobs

#### `ApplicationJob` (base class)
- Automatic retry on `ActiveRecord::Deadlocked` (5 attempts, polynomial backoff)
- Automatic retry on `Redis::BaseError` (3 attempts, 5s wait)
- Discards jobs with missing records (`DeserializationError`)
- Structured logging with duration tracking
- Metrics collection via `MetricsService`

#### `DeviceCleanupJob`
Periodic cleanup of stale resources:
- Stale WebSocket connections (`ConnectionMonitor`)
- Expired heartbeats (`HeartbeatMonitor`)
- Timed-out commands (> 24h)
- Expired file uploads (> 6h)

```ruby
# Run every 5 minutes
DeviceCleanupJob.set(wait: 5.minutes).perform_later
```

#### `MetricsCollectionJob`
Aggregates gauges for the Prometheus `/metrics` endpoint:
- Device counts (total, online, offline)
- Data volume (keylogs, SMS, photos, etc.)
- WebSocket connection stats
- Command queue depth

```ruby
MetricsCollectionJob.perform_later
```

#### `NotificationDispatchJob`
Delivers notifications to configured channels (email, webhook, Slack, Telegram):

```ruby
NotificationDispatchJob.perform_later(
  type: 'device_offline',
  payload: { device_id: 42, message: 'Device went offline' },
  channels: ['slack', 'email']  # optional — defaults to all enabled
)
```

Supported event types: `device_offline`, `device_online`, `alert`, `command_failed`, `data_export_ready`.

### Monitoring

The **Sidekiq Dashboard** page in ActiveAdmin shows queue sizes, latency, and process stats. The full Sidekiq Web UI is available at `/sidekiq` (requires authentication).

---

## Caching Layer

### Architecture

The caching layer uses Redis in production (via `redis_cache_store`) and a memory store in development. Configuration lives in `config/initializers/caching.rb`.

### CacheService (`app/services/cache_service.rb`)

Centralised cache access with domain-specific TTLs:

| Method | TTL | Use case |
|--------|-----|----------|
| `CacheService.device_status(id) { ... }` | 30s | Device online/offline status |
| `CacheService.dashboard_data(key) { ... }` | 5min | Dashboard widget data |
| `CacheService.statistics(scope) { ... }` | 10min | Analytics / statistics pages |

#### Invalidation

```ruby
CacheService.invalidate_device(device_id)   # Single device
CacheService.invalidate_dashboard           # All dashboard caches
CacheService.invalidate_statistics('global') # Specific scope
CacheService.invalidate_all!                # Nuclear option
```

#### Cache Warming

Cache is automatically warmed on production boot. To warm manually:

```ruby
CacheService.warm!
```

This pre-populates dashboard data and device statuses.

### CacheableActions (`app/controllers/concerns/cacheable_actions.rb`)

Controller concern for HTTP-level caching:

```ruby
class Api::DevicesController < ApplicationController
  include CacheableActions

  def show
    @device = Smartphone.find(params[:id])
    # Returns 304 if client cache is fresh
    return if fresh_by(etag: @device, last_modified: @device.updated_at)
    render json: @device
  end

  def index
    @devices = Smartphone.all
    return if fresh_collection?(@devices)
    cache_for 30.seconds
    render json: @devices
  end
end
```

**Available helpers:**
- `fresh_by(etag:, last_modified:)` — conditional GET with ETag
- `fresh_collection?(scope)` — conditional GET for AR collections
- `cache_for(duration, public_cache: false)` — set Cache-Control
- `no_cache!` — disable caching for sensitive responses
- `cached_fragment(key) { ... }` — fragment caching with CacheService

### Toggling Cache in Development

```bash
rails dev:cache   # Toggle caching on/off in development
```

---

## Recommended Recurring Schedule

Add to your scheduler (cron, sidekiq-scheduler, or `whenever`):

| Job | Interval |
|-----|----------|
| `DeviceCleanupJob` | Every 5 minutes |
| `MetricsCollectionJob` | Every 1 minute |
| `DataRetentionJob` | Daily at 3 AM |
| `BackupVerificationJob` | Daily at 6 AM |
