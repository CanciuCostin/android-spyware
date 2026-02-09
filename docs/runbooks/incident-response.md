# Incident Response Runbook

## Severity Levels

| Level    | Description                                | Response Time |
|----------|--------------------------------------------|---------------|
| **P1**   | Service down, no devices can connect       | Immediate     |
| **P2**   | Degraded — partial functionality lost      | 30 min        |
| **P3**   | Minor — cosmetic or non-critical issue     | Next business day |

---

## Triage Checklist

1. **Confirm the issue** — reproduce or verify via monitoring/logs.
2. **Assess blast radius** — how many devices/users are affected?
3. **Assign severity** — use the table above.
4. **Communicate** — notify the team via Slack/Telegram (if notification
   channels are configured).
5. **Mitigate** — apply a quick fix or rollback.
6. **Root-cause** — investigate after mitigation.
7. **Post-mortem** — document findings and preventive actions.

---

## Common Scenarios

### Rails App Not Responding

```bash
# Check container status
docker-compose ps

# Check Rails logs
docker-compose logs --tail=200 rails-app

# Restart the app
docker-compose restart rails-app

# If OOM killed, check resource limits in docker-compose.yml
docker inspect <container_id> | grep -A5 Memory
```

### Database Connection Failures

```bash
# Verify PostgreSQL is running
docker-compose exec db pg_isready

# Check connection count
docker-compose exec db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# If pool exhausted, restart Rails (connections will be recycled)
docker-compose restart rails-app
```

### Redis Down (ActionCable / Real-Time Broken)

```bash
# Check Redis health
docker-compose exec redis redis-cli ping
# Expected: PONG

# Check memory usage
docker-compose exec redis redis-cli info memory | grep used_memory_human

# Restart Redis (ActionCable will auto-reconnect)
docker-compose restart redis
```

### WebRTC Streams Not Working

1. Verify TURN server is running: `docker-compose logs coturn`
2. Test TURN connectivity: open browser console, check ICE candidates.
3. Check firewall allows UDP port 3478 and the configured port range.
4. Verify `TURN_USER`, `TURN_PASSWORD`, `TURN_SECRET` match between
   `.env` and coturn config.

### Devices Not Connecting

1. Verify `DEVICE_AUTH_TOKEN` matches between server `.env` and APK config.
2. Check device can reach the server: `curl http://<server>:8080/health`
3. Check `CommandChannel` logs: `docker-compose logs rails-app | grep CommandChannel`
4. Verify firewall allows inbound connections on port 8080.

---

## Log Locations

| Service     | How to Access                              |
|-------------|--------------------------------------------|
| Rails       | `docker-compose logs rails-app`            |
| PostgreSQL  | `docker-compose logs db`                   |
| Redis       | `docker-compose logs redis`                |
| TURN        | `docker-compose logs coturn`               |
| Jaeger      | UI at `http://<host>:16686`                |
| Audit trail | Admin UI → Audit Logs, or `AuditLog` model |

---

## Escalation

If the issue cannot be resolved within 1 hour:
1. Collect all relevant logs.
2. Note the exact time the issue started and any recent changes (deploys,
   config changes).
3. Escalate to the project maintainer with the collected information.
