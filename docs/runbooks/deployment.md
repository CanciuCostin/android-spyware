# Deployment Runbook

## Prerequisites

- Docker and Docker Compose installed
- Access to the deployment host (SSH or direct)
- `.env` file configured (see `.env.example`)
- Secure credentials generated (see `docs/SECURITY_SETUP.md`)

---

## 1. First-Time Setup

```bash
# Clone the repository
git clone https://github.com/CanciuCostin/android-spyware.git
cd android-spyware

# Copy and edit environment variables
cp .env.example .env
# CRITICAL: Generate secure values for SECRET_KEY_BASE, DEVICE_AUTH_TOKEN,
# REDIS_PASSWORD, POSTGRES_PASSWORD, TURN_SECRET
# See docs/SECURITY_SETUP.md for generation commands.

# Build and start all services
docker-compose -f docker/docker-compose.yml build
docker-compose -f docker/docker-compose.yml up -d

# Verify health
curl http://localhost:8080/health/ready
# Expected: {"status":"ok", ...}
```

---

## 2. Blue-Green Deployment (Zero Downtime)

EagleSpy ships with two compose files for zero-downtime deploys:

| File                       | Port | Purpose     |
|----------------------------|------|-------------|
| `docker-compose.blue.yml`  | 3000 | Blue slot   |
| `docker-compose.green.yml` | 3001 | Green slot  |

### Deploy to the inactive slot

```bash
# Determine which slot is live (check your load balancer config)
# Assume blue is live on :3000, deploy to green on :3001

docker-compose -f docker-compose.green.yml pull
docker-compose -f docker-compose.green.yml up -d

# Wait for health check
until curl -sf http://localhost:3001/health/ready; do sleep 2; done

# Switch load balancer to green (:3001)
# ... (update nginx/HAProxy upstream)

# Tear down old blue
docker-compose -f docker-compose.blue.yml down
```

---

## 3. Database Migrations

```bash
# Run migrations inside the Rails container
docker-compose exec rails-app rails db:migrate

# Verify migration status
docker-compose exec rails-app rails db:migrate:status
```

> **Caution:** Always back up the database before running migrations in
> production. See `docs/runbooks/database-maintenance.md`.

---

## 4. Environment Variables Reference

| Variable                    | Required | Description                          |
|-----------------------------|----------|--------------------------------------|
| `SECRET_KEY_BASE`           | Yes      | Rails encryption key                 |
| `DATABASE_URL`              | Yes      | PostgreSQL connection string         |
| `REDIS_URL`                 | Yes      | Redis connection (with password)     |
| `DEVICE_AUTH_TOKEN`         | Yes      | Shared device authentication token   |
| `TURN_USER`                 | Yes      | TURN server username                 |
| `TURN_PASSWORD`             | Yes      | TURN server password                 |
| `TURN_SECRET`               | Yes      | TURN server secret                   |
| `MAPS_API_KEY`              | No       | Google Maps API key                  |
| `RAILS_MAX_THREADS`         | No       | Puma thread count (default: 5)       |
| `DATA_RETENTION_DAYS`       | No       | Auto-cleanup threshold (default: 30) |

---

## 5. Post-Deployment Checklist

- [ ] `curl /health/ready` returns 200
- [ ] Admin login works at `/admin`
- [ ] WebSocket connection succeeds at `ws://<host>/cable`
- [ ] A test device can connect and send a heartbeat
- [ ] TURN server is reachable: `turnutils_uclient <host>`
- [ ] Jaeger UI is accessible at `:16686` (if tracing enabled)
- [ ] Firewall rules allow ports: 8080, 3478 (TURN), 5432 (Postgres, internal)

---

## 6. Rollback

```bash
# If the new deployment is broken, switch back to the previous slot
# Example: green is broken, switch back to blue
docker-compose -f docker-compose.blue.yml up -d
# Update load balancer to point to blue (:3000)
docker-compose -f docker-compose.green.yml down
```

For database rollback, see `docs/runbooks/database-maintenance.md`.
