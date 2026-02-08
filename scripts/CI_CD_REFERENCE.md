# CI/CD Scripts Reference

Quick reference guide for deployment and CI/CD scripts.

## Deployment Scripts

### Blue-Green Deployment

```bash
# Deploy new version with zero downtime
./scripts/deploy_blue_green.sh v1.2.3

# Deploy latest version
./scripts/deploy_blue_green.sh latest
```

**What it does:**
1. Detects current active environment (blue/green)
2. Starts new environment with new version
3. Runs health checks and smoke tests
4. Switches traffic to new environment
5. Shuts down old environment

### Smoke Tests

```bash
# Run smoke tests against specific URL
./scripts/smoke_test.sh http://localhost:3000

# Run against staging
./scripts/smoke_test.sh https://staging.eaglespy.com
```

**Tests:**
- Health endpoint (`/health`)
- Admin login page (`/admin/login`)
- API health (`/api/health`)

### Traffic Switching

```bash
# Switch to blue environment
./scripts/switch_traffic.sh blue

# Switch to green environment
./scripts/switch_traffic.sh green
```

**Supports:**
- Nginx load balancer
- HAProxy
- Docker Compose proxy
- Environment variables

## CI/CD Workflows

### Security Scan

**Trigger:** Push to main/develop, PRs, weekly schedule

```bash
# Run locally
gem install bundler-audit brakeman
bundler-audit check --update
brakeman -q -z
cd frontend && npm audit
```

### Release Workflow

**Trigger:** Git tags (`v*.*.*`)

```bash
# Create release
git tag -a v1.2.3 -m "Release 1.2.3"
git push origin v1.2.3
```

**Commit Message Format:**
```
feat: Add new feature
fix: Fix bug
chore: Update dependencies
docs: Update documentation
```

## Docker Compose Files

### Blue Environment

```bash
# Start blue environment
docker-compose -f docker-compose.blue.yml up -d

# Stop blue environment
docker-compose -f docker-compose.blue.yml down

# View logs
docker-compose -f docker-compose.blue.yml logs -f
```

**Port:** 3000

### Green Environment

```bash
# Start green environment
docker-compose -f docker-compose.green.yml up -d

# Stop green environment
docker-compose -f docker-compose.green.yml down

# View logs
docker-compose -f docker-compose.green.yml logs -f
```

**Port:** 3001

## Quick Commands

```bash
# Check which environment is active
docker ps --filter "name=eaglespy-prod" --format "{{.Names}}"

# View logs from active environment
docker logs -f eaglespy-prod-blue
docker logs -f eaglespy-prod-green

# Health check
curl http://localhost:3000/health
curl http://localhost:3001/health

# Force recreate environment
docker-compose -f docker-compose.blue.yml up -d --force-recreate

# Clean up stopped containers
docker-compose -f docker-compose.blue.yml down --volumes
```

## Environment Variables

Required for production deployment:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/eaglespy_production
POSTGRES_USER=eaglespy
POSTGRES_PASSWORD=secure_password

# Redis
REDIS_URL=redis://localhost:6379/0

# Rails
SECRET_KEY_BASE=your_secret_key_base
RAILS_ENV=production

# Docker Registry (for CI/CD)
DOCKER_USERNAME=your_username
DOCKER_PASSWORD=your_password
DOCKER_REGISTRY=docker.io/yourorg
```

## Troubleshooting

### Deployment Issues

```bash
# Check environment status
docker ps -a | grep eaglespy

# View deployment logs
docker logs eaglespy-prod-blue
docker logs eaglespy-prod-green

# Check health
curl -v http://localhost:3000/health

# Restart environment
docker-compose -f docker-compose.blue.yml restart
```

### Rollback

```bash
# Quick rollback to previous environment
./scripts/switch_traffic.sh blue  # or green

# Restart previous environment if stopped
docker-compose -f docker-compose.blue.yml up -d
```

### Security Scan Issues

```bash
# Update audit database
gem install bundler-audit
bundler-audit update

# Run specific scans
brakeman --run-all-checks
npm audit fix

# Container scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image eaglespy:latest
```

## See Also

- [CI_CD_GUIDE.md](../CI_CD_GUIDE.md) - Complete CI/CD documentation
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Deployment guide
- [README.md](../README.md) - Project documentation

---

**For detailed information, see [CI_CD_GUIDE.md](../CI_CD_GUIDE.md)**
