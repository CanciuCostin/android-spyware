# Scaling Runbook

## Architecture Overview

```
                    ┌──────────────┐
                    │ Load Balancer│
                    │ (nginx/HAProxy)
                    └──────┬───────┘
                 ┌─────────┼─────────┐
                 ▼         ▼         ▼
           ┌──────────┐ ┌──────────┐ ┌──────────┐
           │ Rails #1 │ │ Rails #2 │ │ Rails #N │
           └────┬─────┘ └────┬─────┘ └────┬─────┘
                │             │             │
        ┌───────┴─────────────┴─────────────┴───────┐
        │              Redis (pub/sub)               │
        └───────────────────┬───────────────────────┘
                            │
                    ┌───────┴───────┐
                    │  PostgreSQL   │
                    └───────────────┘
```

---

## Vertical Scaling

### Rails App (Puma)

Adjust thread and worker counts in `config/puma.rb` or via environment:

```bash
# Increase threads (per-worker concurrency)
RAILS_MAX_THREADS=10

# Increase workers (processes; each gets its own memory)
WEB_CONCURRENCY=4
```

**Resource guidelines per Rails worker:**
- Memory: ~512 MB baseline + 256 MB per thread
- CPU: 0.5–1 core per worker

Update Docker resource limits in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '8'
      memory: 8G
```

### PostgreSQL

```bash
# Key postgresql.conf tuning parameters
shared_buffers = 2GB          # 25% of available RAM
effective_cache_size = 6GB    # 75% of available RAM
work_mem = 64MB               # Per-query sort/hash memory
max_connections = 200         # Match Rails pool * workers + headroom
```

### Redis

```bash
# redis.conf
maxmemory 1gb
maxmemory-policy allkeys-lru
```

---

## Horizontal Scaling

### Multiple Rails Instances

1. All instances must share the same **Redis** for ActionCable pub/sub.
2. All instances must share the same **PostgreSQL** database.
3. Use a load balancer with **sticky sessions** for WebSocket connections
   (or use Redis adapter which handles cross-node broadcast).
4. File uploads use local disk by default — switch to shared storage (NFS,
   S3) when running multiple nodes.

### Load Balancer Configuration (nginx example)

```nginx
upstream eaglespy {
    # Sticky sessions for WebSocket
    ip_hash;
    server rails-1:8080;
    server rails-2:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://eaglespy;
    }

    location /cable {
        proxy_pass http://eaglespy;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

---

## Bottleneck Identification

| Symptom                          | Likely Bottleneck      | Action                        |
|----------------------------------|------------------------|-------------------------------|
| Slow page loads                  | Rails CPU/threads      | Add workers or threads        |
| WebSocket disconnects            | Puma thread exhaustion | Increase `RAILS_MAX_THREADS`  |
| Slow queries                     | PostgreSQL             | Add indexes, tune config      |
| ActionCable lag                  | Redis memory/CPU       | Scale Redis, check eviction   |
| Upload timeouts                  | Network/disk I/O       | Use SSD, increase timeouts    |
| High memory usage                | Too many workers       | Reduce workers, add nodes     |

---

## Monitoring Endpoints

| Endpoint               | What It Checks                   |
|------------------------|----------------------------------|
| `GET /health`          | Overall app health               |
| `GET /health/ready`    | Database + Redis connectivity    |
| `GET /health/live`     | Process is alive                 |
| `GET /api/v1/telemetry/devices` | Connected device count  |
| `GET /api/v1/telemetry/command_queue` | Pending commands   |

---

## Capacity Planning

| Devices | Rails Workers | Threads | PostgreSQL RAM | Redis RAM |
|---------|---------------|---------|----------------|-----------|
| 1–10    | 1             | 5       | 1 GB           | 256 MB    |
| 10–50   | 2             | 5       | 2 GB           | 512 MB    |
| 50–200  | 4             | 10      | 4 GB           | 1 GB      |
| 200+    | 8+ (multi-node)| 10     | 8+ GB          | 2+ GB     |
