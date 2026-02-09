# Database Maintenance Runbook

## Backup

### Automated Backup (recommended)

Add a cron job on the Docker host:

```bash
# Daily backup at 02:00 UTC, retain 7 days
0 2 * * * docker-compose exec -T db pg_dump -U postgres android_spyware_production \
  | gzip > /backups/eaglespy_$(date +\%Y\%m\%d).sql.gz \
  && find /backups -name "eaglespy_*.sql.gz" -mtime +7 -delete
```

### Manual Backup

```bash
# Full database dump
docker-compose exec -T db pg_dump -U postgres android_spyware_production \
  > backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed
docker-compose exec -T db pg_dump -U postgres android_spyware_production \
  | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

---

## Restore

```bash
# Stop the Rails app to prevent writes during restore
docker-compose stop rails-app

# Drop and recreate the database
docker-compose exec db psql -U postgres -c "DROP DATABASE IF EXISTS android_spyware_production;"
docker-compose exec db psql -U postgres -c "CREATE DATABASE android_spyware_production;"

# Restore from backup
cat backup_20260101_020000.sql | docker-compose exec -T db psql -U postgres android_spyware_production

# Or from compressed backup
gunzip -c backup_20260101.sql.gz | docker-compose exec -T db psql -U postgres android_spyware_production

# Restart Rails
docker-compose start rails-app
```

---

## Migrations

### Running Migrations

```bash
# Check pending migrations
docker-compose exec rails-app rails db:migrate:status

# Run pending migrations
docker-compose exec rails-app rails db:migrate

# Rollback last migration
docker-compose exec rails-app rails db:rollback

# Rollback N steps
docker-compose exec rails-app rails db:rollback STEP=3
```

### Migration Best Practices

1. **Always backup** before running migrations in production.
2. **Test migrations** on a staging environment first.
3. **Avoid destructive migrations** during business hours.
4. Keep migrations **reversible** — implement both `up` and `down`.
5. For large tables, use `disable_ddl_transaction!` and `add_index :concurrently`.

---

## Data Retention

EagleSpy auto-cleans old data based on `DATA_RETENTION_DAYS` (default: 30).

To manually clean old data:

```bash
# Remove keylogs older than 30 days
docker-compose exec rails-app rails runner \
  "Keylog.where('created_at < ?', 30.days.ago).delete_all"

# Remove old screenshots
docker-compose exec rails-app rails runner \
  "Screenshot.where('created_at < ?', 30.days.ago).destroy_all"
```

---

## Monitoring Queries

```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('android_spyware_production'));

-- Table sizes (top 10)
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- Active connections
SELECT count(*) FROM pg_stat_activity
WHERE datname = 'android_spyware_production';

-- Long-running queries (> 30s)
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - pg_stat_activity.query_start > interval '30 seconds';

-- Dead tuples (need VACUUM)
SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC;
```

---

## Vacuum and Maintenance

```bash
# Run VACUUM ANALYZE on all tables
docker-compose exec db psql -U postgres android_spyware_production \
  -c "VACUUM ANALYZE;"

# Full vacuum (reclaims disk space, requires exclusive lock)
docker-compose exec db psql -U postgres android_spyware_production \
  -c "VACUUM FULL;"

# Reindex
docker-compose exec db psql -U postgres android_spyware_production \
  -c "REINDEX DATABASE android_spyware_production;"
```
