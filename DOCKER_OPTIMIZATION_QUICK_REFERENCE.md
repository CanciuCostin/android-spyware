# Docker Optimization Quick Reference

## 🚀 Quick Commands

### Build & Run
```bash
# Build optimized images
cd docker && docker-compose build

# Start with resource limits
docker-compose up -d

# Rebuild single service
docker-compose up -d --no-deps --build rails-app
```

### Health Checks
```bash
# Full health status
curl http://localhost:8080/health | jq

# Quick liveness check
curl http://localhost:8080/health/live

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Monitoring
```bash
# Resource usage
docker stats

# Container logs
docker logs -f rails-app

# Health check history
docker inspect --format='{{json .State.Health}}' rails-app | jq
```

### Optimization
```bash
# Run optimization script
./scripts/optimize_images.sh all

# Analyze image sizes
docker images --format "table {{.Repository}}\t{{.Size}}"

# Clean unused resources
docker system prune -a
```

## 📊 Resource Limits Reference

| Service    | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|------------|-----------|--------------|--------------|-----------------|
| Rails      | 4 cores   | 4 GB         | 2 cores      | 2 GB            |
| PostgreSQL | 2 cores   | 2 GB         | 1 core       | 1 GB            |
| Redis      | 0.5 core  | 512 MB       | 0.25 core    | 256 MB          |
| Frontend   | 0.5 core  | 256 MB       | 0.25 core    | 128 MB          |
| Jaeger     | 1 core    | 512 MB       | -            | -               |
| CoTURN     | 1 core    | 512 MB       | 0.5 core     | 256 MB          |

## 🏥 Health Endpoints

| Endpoint          | Purpose                      | Use Case                        |
|-------------------|------------------------------|---------------------------------|
| `/health`         | Full system health           | Monitoring, diagnostics         |
| `/health/live`    | Liveness probe               | Kubernetes/Docker liveness      |
| `/health/ready`   | Readiness probe              | Kubernetes/Docker readiness     |

## 📏 Image Size Targets

- **Rails App**: 400-500 MB (multi-stage)
- **Frontend**: 25-40 MB (nginx alpine)
- **PostgreSQL**: 314 MB (alpine)
- **Redis**: 32 MB (alpine)

## 🔧 Common Troubleshooting

### Container Unhealthy
```bash
# Check logs
docker logs rails-app --tail 100

# Manual health check
docker exec rails-app curl http://localhost:3000/health/live

# Restart container
docker-compose restart rails-app
```

### OOM (Out of Memory)
```bash
# Check memory usage
docker stats rails-app --no-stream

# Increase limit in docker-compose.yml
resources:
  limits:
    memory: 6G
```

### Slow Performance
```bash
# Check CPU throttling
docker stats

# Scale workers
WEB_CONCURRENCY=4 docker-compose up -d rails-app
```

## 🔒 Security Checklist

- ✅ Non-root users in all containers
- ✅ Multi-stage builds (no build tools in production)
- ✅ Minimal base images (alpine/slim)
- ✅ Resource limits configured
- ✅ Health checks enabled
- ✅ Logging limits set
- ✅ Secrets via environment variables
- ✅ .dockerignore configured

## 🎯 Performance Tuning

### PostgreSQL
```yaml
command: postgres -c shared_buffers=512MB -c max_connections=200
```

### Redis
```yaml
command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

### Puma (Rails)
```env
RAILS_MAX_THREADS=10
WEB_CONCURRENCY=4
```

## 📝 Maintenance Schedule

- **Daily**: Check health status
- **Weekly**: Review logs and resource usage
- **Monthly**: Update base images, rebuild
- **Quarterly**: Security scan, performance test

---
**Quick Start**: `cd docker && docker-compose up -d && curl http://localhost:8080/health`
