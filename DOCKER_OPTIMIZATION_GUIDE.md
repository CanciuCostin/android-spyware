# Docker Optimization Guide

Complete guide for optimized Docker containers with multi-stage builds, minimal image sizes, health checks, and resource limits.

## 🎯 Optimization Goals

- **Size Reduction**: 50-70% smaller images using multi-stage builds
- **Security**: Non-root users, minimal attack surface
- **Performance**: Resource limits and efficient layer caching
- **Reliability**: Health checks and restart policies
- **Production-Ready**: Proper logging, monitoring, and graceful shutdown

## 📊 Image Size Improvements

### Before Optimization
- Rails App: ~1.2GB
- Database: ~314MB
- Redis: ~110MB

### After Optimization
- Rails App: ~400-500MB (60% reduction)
- Frontend: ~25-40MB (nginx alpine)
- Database: ~314MB (already optimized)
- Redis: ~32MB (alpine variant)

## 🏗️ Multi-Stage Dockerfile Strategy

### Rails Application (`docker/app-rails-server/Dockerfile`)

**Stage 1: Builder**
- Full Ruby image with build tools
- Install gems and compile assets
- Remove unnecessary files (*.c, *.o, caches)

**Stage 2: Runtime**
- Slim Ruby image (50% smaller)
- Only runtime dependencies
- Copy compiled artifacts from builder
- Non-root user execution

**Key Optimizations:**
```dockerfile
# Layer caching - dependencies first
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Remove build artifacts
RUN find /usr/local/bundle/gems/ -name "*.c" -delete
RUN find /usr/local/bundle/gems/ -name "*.o" -delete

# Reduce memory fragmentation
ENV MALLOC_ARENA_MAX=2
```

### Frontend Application (`frontend/Dockerfile`)

**Stage 1: Builder**
- Node 18 Alpine (minimal)
- npm ci for deterministic installs
- Production build

**Stage 2: Nginx**
- Nginx Alpine (ultra-minimal)
- Only built static files
- Custom nginx config
- Non-root nginx user

## 🏥 Health Checks

### Implementation Levels

#### 1. Application Health Endpoint
Location: `app/controllers/health_controller.rb`

**Endpoints:**
- `GET /health` - Full system health with dependencies
- `GET /health/ready` - Readiness probe (can accept traffic)
- `GET /health/live` - Liveness probe (process is running)

**Response Example:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "5.0.0",
  "environment": "production",
  "checks": {
    "database": {
      "status": "ok",
      "latency_ms": 2.5,
      "pool_size": 5,
      "active_connections": 2
    },
    "redis": {
      "status": "ok",
      "latency_ms": 1.2
    },
    "disk_space": {
      "status": "ok",
      "usage_percent": 45
    },
    "memory": {
      "status": "ok",
      "usage_percent": 67
    }
  }
}
```

#### 2. Docker Health Checks
Configured in Dockerfile and docker-compose.yml:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health/live"]
  interval: 30s      # Check every 30 seconds
  timeout: 10s       # Fail if no response in 10s
  retries: 3         # Mark unhealthy after 3 failures
  start_period: 60s  # Grace period for startup
```

#### 3. Dependency Health Checks

**PostgreSQL:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Redis:**
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
```

**Frontend (Nginx):**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 3s
  retries: 3
```

## 💾 Resource Limits

### Docker Compose Resource Configuration

#### Rails Application
```yaml
deploy:
  resources:
    limits:
      cpus: '4'       # Max 4 CPU cores
      memory: 4G      # Max 4GB RAM
    reservations:
      cpus: '2'       # Guaranteed 2 cores
      memory: 2G      # Guaranteed 2GB RAM
```

#### Database (PostgreSQL)
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '1'
      memory: 1G
```

#### Redis
```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

#### Frontend (Nginx)
```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 256M
    reservations:
      cpus: '0.25'
      memory: 128M
```

### Restart Policies

```yaml
deploy:
  restart_policy:
    condition: on-failure    # Only restart on failure
    delay: 5s               # Wait 5s before restart
    max_attempts: 3         # Try max 3 times
    window: 120s            # Within 2 minute window
```

### Logging Limits

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"    # Max 10MB per file
    max-file: "3"      # Keep 3 files (30MB total)
```

## 🚀 Build and Deployment

### Build Optimized Images

```bash
# Linux/Mac
./scripts/optimize_images.sh build

# Windows
scripts\optimize_images.bat build

# Docker Compose
cd docker
docker-compose build
```

### Analyze Image Sizes

```bash
# Linux/Mac
./scripts/optimize_images.sh analyze

# Docker command
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### Start with Resource Limits

```bash
cd docker
docker-compose up -d
```

### Check Health Status

```bash
# Overall health
curl http://localhost:8080/health | jq

# Liveness
curl http://localhost:8080/health/live

# Readiness
curl http://localhost:8080/health/ready

# Docker health status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"
```

## 📈 Monitoring

### Container Resource Usage

```bash
# Real-time stats
docker stats

# Specific container
docker stats rails-app

# Export metrics
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Health Check Logs

```bash
# View health check results
docker inspect --format='{{json .State.Health}}' rails-app | jq

# Container logs
docker logs -f rails-app

# Health endpoint logs
docker exec rails-app tail -f log/production.log | grep -i health
```

## 🔧 Troubleshooting

### Container Fails Health Check

**Symptoms:**
- Container shows as "unhealthy" in `docker ps`
- Application not responding to health probes

**Solutions:**
1. Check application logs:
   ```bash
   docker logs rails-app
   ```

2. Verify health endpoint manually:
   ```bash
   docker exec rails-app curl -f http://localhost:3000/health/live
   ```

3. Increase `start_period` if startup is slow:
   ```yaml
   healthcheck:
     start_period: 90s  # Give more time to start
   ```

4. Check database connectivity:
   ```bash
   docker exec rails-app rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a"
   ```

### Out of Memory (OOM) Errors

**Symptoms:**
- Container exits with code 137
- "Killed" messages in logs

**Solutions:**
1. Increase memory limit:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 6G
   ```

2. Monitor actual usage:
   ```bash
   docker stats rails-app
   ```

3. Optimize application:
   - Reduce RAILS_MAX_THREADS
   - Enable database connection pooling
   - Add memory limits to child processes

### Slow Build Times

**Optimization:**
1. Use build cache:
   ```yaml
   build:
     cache_from:
       - eaglespy:latest
   ```

2. Order Dockerfile layers by change frequency
3. Use `.dockerignore` to exclude unnecessary files
4. Parallel builds:
   ```bash
   docker-compose build --parallel
   ```

### Image Too Large

**Reduction Strategies:**
1. Multi-stage builds (already implemented)
2. Remove development dependencies
3. Clean package caches
4. Use slim/alpine base images
5. Analyze with dive:
   ```bash
   dive eaglespy-rails:latest
   ```

## 🔒 Security Best Practices

### Non-Root User
All containers run as non-root users:
- Rails: `rails` user (UID 1000)
- Frontend: `nginx` user (UID 101)
- Database: `postgres` user

### Minimal Attack Surface
- Only runtime dependencies in final image
- No build tools in production
- No unnecessary packages
- Regular base image updates

### Resource Isolation
- CPU and memory limits prevent resource exhaustion
- Separate networks for service isolation
- Volume permissions restricted

## 📝 Configuration Reference

### Environment Variables

**Database:**
- `POSTGRES_USER` - Database username
- `POSTGRES_PASSWORD` - Database password
- `ANDROIDSPYWARE_DATABASE_HOST` - Database hostname

**Redis:**
- `REDIS_URL` - Redis connection URL
- `REDIS_PASSWORD` - Redis authentication password

**Rails:**
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV` - Environment (production/development)
- `RAILS_MAX_THREADS` - Puma thread pool size

### Volume Mounts

```yaml
volumes:
  - db:/var/lib/postgresql/data          # Database persistence
  - redis_data:/data                     # Redis persistence
  - bundle_cache:/usr/local/bundle       # Gem cache
  - ../backups:/backups                  # Backup storage
```

## 🎯 Performance Tuning

### PostgreSQL
```yaml
command: postgres 
  -c shared_buffers=512MB
  -c effective_cache_size=2GB
  -c max_connections=200
```

### Redis
```yaml
command: redis-server
  --maxmemory 512mb
  --maxmemory-policy allkeys-lru
  --appendonly yes
```

### Puma (Rails)
```ruby
# config/puma.rb
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 10 }
threads threads_count, threads_count
workers ENV.fetch("WEB_CONCURRENCY") { 4 }
preload_app!
```

## 📚 Additional Resources

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Docker Compose Resources](https://docs.docker.com/compose/compose-file/deploy/)
- [Container Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

## 🔄 Maintenance

### Regular Tasks

1. **Weekly:**
   - Review container health status
   - Check resource usage trends
   - Rotate logs if needed

2. **Monthly:**
   - Update base images
   - Rebuild images with latest patches
   - Review and optimize resource limits

3. **Quarterly:**
   - Security audit with trivy/clair
   - Performance testing under load
   - Capacity planning review

### Update Procedure

```bash
# 1. Pull latest base images
docker-compose pull

# 2. Rebuild with no cache
docker-compose build --no-cache

# 3. Test in staging
docker-compose -f docker-compose.staging.yml up -d

# 4. Health check
curl http://staging.example.com/health

# 5. Deploy to production
docker-compose up -d --no-deps --build rails-app
```

---

**Last Updated:** 2024-01-15  
**Maintained By:** EagleSpy Development Team
