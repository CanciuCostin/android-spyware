# Observability Guide – EagleSpy V5

## Overview

EagleSpy V5 includes a built-in observability stack covering structured logging,
metrics collection, health checks, and error tracking. No external dependencies
(Prometheus server, Grafana, etc.) are required—all data is produced in-process
and exposed via standard HTTP endpoints.

---

## 1. Structured Logging

**File:** `app/services/structured_logger.rb`

### Usage

```ruby
StructuredLogger.info("Device connected", device_id: "abc-123")
StructuredLogger.error("Upload failed", error: exception, device_id: "abc-123")
StructuredLogger.warn("Slow query", duration_ms: 450, request_id: "req-xyz")
```

### Features

| Feature | Details |
|---------|---------|
| Format | JSON (one object per line) |
| Levels | `debug`, `info`, `warn`, `error`, `fatal` |
| Request ID | Auto-attached from `RequestStore` |
| Device ID | Pass via `device_id:` keyword |
| PII redaction | Emails, phones, SSNs, card numbers, passwords, tokens, secrets, API keys |

### Configuration

**File:** `config/initializers/logging.rb`

- JSON formatter applied automatically in non-development environments.
- Log rotation: daily, max 30 files (production, file-based logging).
- Development keeps the default Rails formatter for readability.

---

## 2. Metrics Collection

**File:** `app/services/metrics_service.rb`

### Metric Types

| Type | Example | API |
|------|---------|-----|
| Counter | `commands_sent_total` | `MetricsService.increment(:commands_sent_total)` |
| Gauge | `active_devices` | `MetricsService.set_gauge(:active_devices, 5)` |
| Histogram | `command_response_time` | `MetricsService.observe_histogram(:command_response_time, 0.342)` |

### Built-in Counters

- `commands_sent_total` – total commands dispatched
- `commands_failed_total` – commands that failed
- `errors_total` – application errors (by category)
- `uploads_completed_total` – finished file uploads

### Built-in Gauges (collected at `/metrics`)

- `active_devices`, `total_devices`
- `websocket_connections`
- `total_sms`, `total_contacts`, `total_pictures`, `total_recordings`
- `total_locations`, `total_call_logs`, `total_keylogs`
- `error_rate_per_minute`, `error_spike`
- `system_memory_usage_percent`, `system_disk_usage_percent`
- `db_pool_size`, `db_pool_active`
- `process_resident_memory_bytes`, `process_uptime_seconds`

### Built-in Histograms

- `command_response_time` – seconds from send to ack
- `upload_duration` – seconds per file upload

### Instrumenting Your Code

```ruby
# In a controller or service:
start = Time.current
# ... do work ...
duration = Time.current - start
MetricsService.observe_histogram(:command_response_time, duration)
MetricsService.increment(:commands_sent_total, labels: { type: 'shell' })
```

---

## 3. Health Check Endpoints

**File:** `app/controllers/health_controller.rb`

| Endpoint | Purpose | When to Use |
|----------|---------|-------------|
| `GET /health` | Full check (DB, Redis, ActionCable, disk, memory) | Dashboards, manual checks |
| `GET /health/live` | Liveness probe | K8s `livenessProbe` |
| `GET /health/ready` | Readiness probe (DB + Redis + ActionCable) | K8s `readinessProbe` |
| `GET /health/startup` | Startup probe (DB + migrations) | K8s `startupProbe` |

### Example Response (`/health`)

```json
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "version": "5.0.0",
  "environment": "production",
  "uptime_seconds": 86400,
  "checks": {
    "database": { "status": "ok", "latency_ms": 1.23 },
    "redis": { "status": "ok", "latency_ms": 0.45 },
    "action_cable": { "status": "ok", "adapter": "redis" },
    "disk_space": { "status": "ok", "usage_percent": 42 },
    "memory": { "status": "ok", "usage_percent": 65 }
  }
}
```

### Kubernetes Configuration

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 15

readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10

startupProbe:
  httpGet:
    path: /health/startup
    port: 3000
  failureThreshold: 30
  periodSeconds: 5
```

---

## 4. Prometheus Metrics Endpoint

**File:** `app/controllers/metrics_controller.rb`

```
GET /metrics
Content-Type: text/plain; version=0.0.4; charset=utf-8
```

Returns all counters, gauges, and histograms in Prometheus exposition format.
Suitable for scraping by Prometheus, Datadog Agent, or any compatible collector.

### Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: 'eaglespy'
    scrape_interval: 30s
    static_configs:
      - targets: ['eaglespy-host:3000']
    metrics_path: '/metrics'
```

---

## 5. Error Tracking

**File:** `app/services/error_tracker.rb`

### Features

- **Automatic capture** – `StructuredLogger.error` / `.fatal` auto-feed errors.
- **Classification** – database, redis, websocket, network, timeout, adb, metasploit, system, application.
- **Frequency tracking** – errors per minute, spike detection.
- **Spike detection** – alerts when >20 errors in 60 seconds.
- **Context** – request_id, device_id, controller, action.

### Usage

```ruby
# Manual capture
ErrorTracker.capture("Payment failed", error: exception, device_id: "abc")

# Query
ErrorTracker.summary           # => { total:, by_class:, by_category:, recent:, error_rate_per_minute:, spike: }
ErrorTracker.spike_detected?   # => true/false
ErrorTracker.recent_errors(10) # => last 10 error entries
ErrorTracker.error_rate        # => errors per minute (float)
```

---

## 6. ActiveAdmin Dashboard

Navigate to **Admin → 📊 Observability** to view:

- Health status (DB, Redis, uptime)
- Active devices and WebSocket connections
- Error rate with spike indicator
- Error breakdown by category
- Recent errors list
- Counter and histogram metrics
- Links to all observability endpoints

---

## 7. File Reference

| File | Purpose |
|------|---------|
| `app/services/structured_logger.rb` | JSON structured logging with PII redaction |
| `app/services/metrics_service.rb` | Counter/gauge/histogram collection |
| `app/services/error_tracker.rb` | Error capture, classification, spike detection |
| `app/controllers/health_controller.rb` | Health check endpoints |
| `app/controllers/metrics_controller.rb` | Prometheus metrics endpoint |
| `app/admin/observability.rb` | ActiveAdmin observability dashboard |
| `config/initializers/logging.rb` | JSON log formatter, rotation |
| `config/routes.rb` | Routes for `/health/*` and `/metrics` |

---

## 8. Integration with Existing Tracing

EagleSpy V5 already uses OpenTelemetry for distributed tracing
(see `docs/TRACING_GUIDE.md`). The observability stack complements tracing:

- **Tracing** = request-level spans (Jaeger/Zipkin)
- **Metrics** = aggregate counters/gauges (Prometheus)
- **Logging** = structured JSON logs (ELK/CloudWatch)
- **Error tracking** = classified error stream with spike detection
