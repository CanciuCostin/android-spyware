# Troubleshooting Guide

## Quick Diagnostics

```bash
# Check all service status
docker-compose ps

# View recent logs (last 100 lines)
docker-compose logs --tail=100

# Check system resources
docker stats --no-stream
```

---

## Common Issues

### 1. "Connection Refused" When Accessing Admin UI

**Symptoms:** Browser shows ERR_CONNECTION_REFUSED at `http://localhost:8080`.

**Causes & Fixes:**

| Cause                    | Fix                                          |
|--------------------------|----------------------------------------------|
| Rails container not running | `docker-compose up -d rails-app`          |
| Port conflict            | Check `netstat -an | findstr 8080`           |
| Docker not running       | Start Docker Desktop                         |
| Wrong port               | Check `docker-compose.yml` for mapped port   |

---

### 2. Device Not Appearing Online

**Symptoms:** Device is running the APK but doesn't show in the admin panel.

**Checklist:**
1. ✅ APK was built with the correct server IP/port.
2. ✅ `DEVICE_AUTH_TOKEN` in `.env` matches the token in the APK.
3. ✅ Firewall allows inbound on port 8080.
4. ✅ Device has network connectivity to the server.
5. ✅ Check ActionCable logs:
   ```bash
   docker-compose logs rails-app | grep -i "commandchannel\|subscribed\|rejected"
   ```

---

### 3. WebRTC Stream Shows Black Screen

**Symptoms:** Stream starts but video is black or audio is silent.

**Checklist:**
1. ✅ TURN server is running: `docker-compose logs coturn`
2. ✅ TURN credentials match between `.env` and server config.
3. ✅ Firewall allows UDP on port 3478 and the relay port range.
4. ✅ Browser allows camera/microphone access (check permissions).
5. ✅ Test TURN connectivity with a WebRTC tester tool.
6. ✅ Check SignalingChannel logs:
   ```bash
   docker-compose logs rails-app | grep -i "signalingchannel\|offer\|answer\|ice"
   ```

---

### 4. Database Migration Errors

**Symptoms:** `rails db:migrate` fails with errors.

**Common fixes:**

```bash
# Check current migration status
docker-compose exec rails-app rails db:migrate:status

# If "NO FILE" entries exist, the migration file was deleted
# Manually mark as done:
docker-compose exec rails-app rails runner \
  "ActiveRecord::SchemaMigration.create!(version: '20240101000000')"

# If schema is out of sync, reload
docker-compose exec rails-app rails db:schema:load
# WARNING: This drops all data! Only use on fresh databases.
```

---

### 5. Redis Memory Exhaustion

**Symptoms:** ActionCable disconnects, real-time features stop working.

```bash
# Check Redis memory
docker-compose exec redis redis-cli info memory

# Flush old data (careful — clears all caches)
docker-compose exec redis redis-cli FLUSHDB

# Set memory limit
docker-compose exec redis redis-cli CONFIG SET maxmemory 512mb
docker-compose exec redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

---

### 6. Slow Performance

**Diagnosis:**

```bash
# Check which container is using resources
docker stats --no-stream

# Check PostgreSQL slow queries
docker-compose exec db psql -U postgres android_spyware_production \
  -c "SELECT pid, now() - query_start AS duration, query
      FROM pg_stat_activity WHERE state = 'active'
      ORDER BY duration DESC LIMIT 5;"

# Check Puma thread saturation
docker-compose logs rails-app | grep -i "backlog\|busy"
```

**Fixes:**
- Add database indexes for slow queries.
- Increase `RAILS_MAX_THREADS` if threads are saturated.
- Enable query caching in production.
- See `docs/runbooks/scaling.md` for capacity planning.

---

### 7. File Upload Failures

**Symptoms:** Uploads fail or files are incomplete.

**Checklist:**
1. ✅ Disk space available: `docker-compose exec rails-app df -h`
2. ✅ File size within limit (default 10 MB).
3. ✅ Check for expired uploads:
   ```bash
   docker-compose exec rails-app rails runner \
     "puts Dir.glob('tmp/uploads/*').count"
   ```
4. ✅ Run cleanup: `POST /file_transfers/cleanup_expired_uploads`

---

### 8. "Secret Key Base" Errors

**Symptoms:** Rails crashes with `Missing secret_key_base` or encryption errors.

```bash
# Generate a new secret
docker-compose exec rails-app rails secret
# Copy the output to .env as SECRET_KEY_BASE

# Restart
docker-compose restart rails-app
```

---

## Log Grep Patterns

```bash
# Find errors
docker-compose logs rails-app 2>&1 | grep -i "error\|exception\|fatal"

# Track a specific device
docker-compose logs rails-app 2>&1 | grep "device_abc123"

# ActionCable connection issues
docker-compose logs rails-app 2>&1 | grep -i "cable\|websocket\|channel"

# Authentication failures
docker-compose logs rails-app 2>&1 | grep -i "unauthorized\|rejected\|denied"
```

---

## Getting Help

1. Check the [API docs](../api/README.md) for endpoint details.
2. Review [Architecture Decision Records](../adr/) for design context.
3. File an issue on the GitHub repository with logs and reproduction steps.
