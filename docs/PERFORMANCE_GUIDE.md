# Performance Guide — EagleSpy V5

This guide documents the performance optimizations in EagleSpy V5
and how to monitor, test, and tune the system.

---

## Table of Contents

1. [Performance Tests](#performance-tests)
2. [WebSocket Optimization](#websocket-optimization)
3. [Database Performance](#database-performance)
4. [Rake Tasks](#rake-tasks)
5. [Monitoring](#monitoring)
6. [Tuning Recommendations](#tuning-recommendations)

---

## Performance Tests

Performance specs live in `spec/performance/` and cover four areas:

| Spec File | What It Tests |
|---|---|
| `load_test_spec.rb` | 100+ concurrent device connections, command response times, dashboard rendering with many devices, memory tracking |
| `upload_stress_spec.rb` | 10 simultaneous uploads, 100MB+ large files, chunk reassembly speed, cleanup under load |
| `database_benchmark_spec.rb` | Query performance for large datasets, index effectiveness, N+1 detection, pagination, bulk operations |
| `memory_leak_spec.rb` | Long-running connection simulation, repeated command cycles, upload/download cycles, memory growth tracking |

Run them with:

```bash
bundle exec rspec spec/performance/ --tag performance
```

---

## WebSocket Optimization

### Message Batching

`WebsocketOptimizer.enqueue` groups messages by stream and flushes
them after a 100 ms window or when the batch reaches 50 messages.
Priority messages (commands, errors, pings/pongs) bypass batching.

Use in channels via the `MessageBatching` concern:

```ruby
class MyChannel < ApplicationCable::Channel
  include MessageBatching

  def some_action(data)
    batched_broadcast("my_stream", { type: 'update', data: data })
  end
end
```

### Compression

Payloads larger than 1 KB are automatically gzip-compressed when
using `WebsocketOptimizer.smart_broadcast`. The client receives a
JSON envelope with `_compressed: true` and Base64-encoded data.

```ruby
WebsocketOptimizer.smart_broadcast("stream", large_payload)
```

### Binary Protocol

For high-frequency messages (ping, pong, heartbeat, location_update,
device_status, command_ack), a compact binary protocol reduces
frame overhead:

```ruby
binary = WebsocketOptimizer.encode_binary('ping', { ts: Time.now.to_i })
decoded = WebsocketOptimizer.decode_binary(binary)
# => { type: 'ping', payload: { 'ts' => ... } }
```

### Connection Pooling

Connections per IP are limited to 10 (configurable). Excess
connections are rejected with a log warning:

```ruby
WebsocketOptimizer.register_connection(ip, device_id)  # => true/false
WebsocketOptimizer.release_connection(ip, device_id)
```

### Adaptive Heartbeat

`WebsocketOptimizer.adaptive_heartbeat_interval(device_id)` returns
an interval between 10 s and 120 s based on latency, reconnect
history, and idle time. Stable devices get faster intervals; flaky
devices get slower ones to reduce churn.

---

## Database Performance

### Key Optimizations

- **Cursor-based pagination** via `OptimizedQueries.location_history`
  and `OptimizedQueries.recent_keylogs_cursor` for large tables.
- **Materialized view** `device_summaries_cached` for the dashboard.
- **Composite indexes** on `(smartphone_id, created_at)` for all
  time-series tables.
- **Counter caches** on `smartphones` for `keylogs_count` and
  `commands_count`.
- **Batch inserts** via `insert_all` for bulk keylog ingestion.

### Diagnostics

```ruby
OptimizedQueries.table_statistics     # Table sizes
OptimizedQueries.index_usage_stats    # Index utilization
OptimizedQueries.slow_queries         # Slow query report
OptimizedQueries.connection_pool_stats # Connection pool health
```

---

## Rake Tasks

### `rake perf:benchmark`

Runs timed benchmarks against database, Redis, and connection
operations. Use to establish baselines and detect regressions.

### `rake perf:profile`

Measures RSS memory before and after key operations (queries,
command creation, Redis ops). Useful for spotting memory-heavy code
paths.

### `rake perf:memory`

Runs 10 simulated workload cycles, printing RSS, heap slots, and
GC statistics per cycle. Use to detect memory leaks over time.

### `rake db:maintenance:performance_report`

Generates a full database performance report including table sizes,
connection pool stats, slow queries, and missing index suggestions.

---

## Monitoring

### Prometheus Metrics

`MetricsService` exposes counters, gauges, and histograms in
Prometheus text format at the `/metrics` endpoint:

```
process_resident_memory_bytes
process_uptime_seconds
commands_sent_total{type="shell"}
command_response_time (histogram)
active_devices (gauge)
```

### Connection Monitor

```ruby
ConnectionMonitor.statistics
# => { total_connections: 42, device_connections: 38, ... }
```

### Heartbeat Monitor

```ruby
HeartbeatMonitor.get_all_online_devices  # => ["device-abc", ...]
HeartbeatMonitor.cleanup_stale_heartbeats # => removes offline devices
```

---

## Tuning Recommendations

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ACTION_CABLE_WORKERS` | `4` | Worker threads for WebSocket message processing |
| `WS_MAX_MESSAGE_SIZE` | `1048576` | Maximum WebSocket message size in bytes (1 MB) |
| `REDIS_POOL_SIZE` | `RAILS_MAX_THREADS + 10` | Redis connection pool size |
| `RAILS_MAX_THREADS` | `5` | Puma/WEBrick thread count |

### Action Cable

- Increase `ACTION_CABLE_WORKERS` if message processing backs up.
- Lower `WS_MAX_MESSAGE_SIZE` if untrusted clients send large frames.
- Use the Redis adapter in production (`config/cable.yml`).

### Database

- Run `rake db:maintenance:full` weekly to vacuum and analyze.
- Monitor `OptimizedQueries.slow_queries` and add indexes as needed.
- Use `find_each(batch_size: 1000)` for iterating large result sets.

### Memory

- Run `rake perf:memory` periodically to detect growth trends.
- Keep the Redis pool sized to match thread concurrency.
- Use `GC.compact` (Ruby 2.7+) in production for reduced fragmentation.
