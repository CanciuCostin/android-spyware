# Docker Optimization Deployment Checklist

Use this checklist to deploy the optimized Docker containers to production.

## Pre-Deployment

### 1. Validation
- [ ] Run validation script: `ruby scripts/validate_docker_optimization.rb`
- [ ] All required files present
- [ ] Health endpoints configured
- [ ] Resource limits set

### 2. Configuration
- [ ] Review `.env` file for production values
- [ ] Set strong passwords for POSTGRES_PASSWORD, REDIS_PASSWORD
- [ ] Configure DEVICE_AUTH_TOKEN
- [ ] Set SECRET_KEY_BASE (generate with `rails secret`)
- [ ] Update TURN_USER and TURN_PASSWORD
- [ ] Configure external IP for CoTURN

### 3. Security Review
- [ ] All containers run as non-root users
- [ ] No Docker socket mounted
- [ ] Secrets managed via environment variables
- [ ] .dockerignore excludes sensitive files
- [ ] Resource limits configured (prevent DoS)

### 4. Build Optimization
- [ ] .dockerignore files in place
- [ ] Multi-stage Dockerfiles configured
- [ ] Asset precompilation enabled
- [ ] Build cache strategy implemented

## Build Phase

### 5. Image Building
```bash
cd docker
docker-compose build --no-cache
```

- [ ] Rails image built successfully
- [ ] Frontend image built successfully
- [ ] No build errors
- [ ] Image sizes reasonable (Rails ~400-500MB, Frontend ~25-40MB)

### 6. Image Verification
```bash
docker images | grep eaglespy
./scripts/optimize_images.sh analyze
```

- [ ] Image sizes within targets
- [ ] All required images present
- [ ] No dangling images

### 7. Security Scan (if trivy installed)
```bash
trivy image eaglespy-rails:latest
trivy image eaglespy-frontend:latest
```

- [ ] No critical vulnerabilities
- [ ] High-severity issues addressed

## Deployment Phase

### 8. Initial Startup
```bash
docker-compose up -d
```

- [ ] All containers started
- [ ] No immediate crashes
- [ ] Logs show successful initialization

### 9. Health Check Verification
```bash
# Wait 60 seconds for startup
sleep 60

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Test health endpoints
curl http://localhost:8080/health
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

- [ ] All containers show "healthy" status
- [ ] Health endpoints return 200 OK
- [ ] Database check passes
- [ ] Redis check passes

### 10. Resource Monitoring
```bash
docker stats --no-stream
```

- [ ] CPU usage within limits
- [ ] Memory usage within limits
- [ ] No containers at limit
- [ ] No OOM errors in logs

### 11. Functional Testing
- [ ] Admin login works: http://localhost:8080/admin
- [ ] Frontend loads: http://localhost:5173
- [ ] Device connection test passes
- [ ] WebRTC signaling works
- [ ] File uploads work
- [ ] Database queries successful

### 12. Log Verification
```bash
docker logs rails-app --tail 50
docker logs frontend --tail 50
docker logs db --tail 50
docker logs redis --tail 50
```

- [ ] No error messages
- [ ] Rails server running
- [ ] Database connected
- [ ] Redis connected

## Post-Deployment

### 13. Monitoring Setup
- [ ] Health endpoints monitored
- [ ] Resource usage tracked
- [ ] Log aggregation configured
- [ ] Alert rules defined

### 14. Backup Verification
- [ ] Database backup scheduled
- [ ] Volume backups configured
- [ ] Backup restoration tested

### 15. Documentation
- [ ] Team trained on health endpoints
- [ ] Troubleshooting guide reviewed
- [ ] Runbook updated
- [ ] On-call procedures documented

### 16. Performance Baseline
- [ ] Response time measured
- [ ] Throughput tested
- [ ] Resource usage baselined
- [ ] Capacity limits documented

## Rollback Plan

### If Issues Occur
1. **Immediate Actions**:
   ```bash
   docker-compose down
   docker-compose -f docker-compose.old.yml up -d
   ```

2. **Check Logs**:
   ```bash
   docker logs rails-app > rollback_logs.txt
   ```

3. **Notify Team**:
   - Document issue
   - Time of occurrence
   - Error messages
   - Actions taken

## Maintenance Schedule

### Daily
- [ ] Check container health: `docker ps`
- [ ] Review health endpoint status
- [ ] Monitor resource usage

### Weekly
- [ ] Review container logs
- [ ] Check disk space
- [ ] Verify backups

### Monthly
- [ ] Update base images
- [ ] Rebuild containers
- [ ] Security scan
- [ ] Performance review

### Quarterly
- [ ] Load testing
- [ ] Disaster recovery drill
- [ ] Capacity planning
- [ ] Documentation update

## Success Criteria

- ✅ All containers running and healthy
- ✅ Health endpoints returning 200 OK
- ✅ Resource usage within limits
- ✅ No errors in logs
- ✅ Application fully functional
- ✅ Monitoring and alerts active
- ✅ Backups verified
- ✅ Team trained

## Emergency Contacts

- **DevOps Lead**: [Name/Contact]
- **Database Admin**: [Name/Contact]
- **Security Team**: [Name/Contact]
- **On-Call Engineer**: [Name/Contact]

## Notes

_Use this space to document deployment-specific details:_

---

**Deployment Date**: _________________  
**Deployed By**: _________________  
**Environment**: _________________  
**Version**: _________________  

**Sign-off**:
- [ ] DevOps Lead
- [ ] Security Team
- [ ] Project Manager
