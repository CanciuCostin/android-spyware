#!/bin/bash
# Quick Restore Script - Restore from latest backup

set -e

BACKUP_FILE="${1:-$(ls -t /backups/eaglespy_db_*.sql.gz 2>/dev/null | head -1)}"

if [ -z "$BACKUP_FILE" ]; then
  echo "Error: No backup file found"
  echo "Usage: $0 [backup_file]"
  echo "Example: $0 /backups/eaglespy_db_20260208_020000.sql.gz"
  exit 1
fi

echo "================================================================"
echo "EagleSpy Database Restore"
echo "================================================================"
echo "Backup file: $BACKUP_FILE"
echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo "Backup date: $(stat -c %y "$BACKUP_FILE" 2>/dev/null || stat -f %Sm "$BACKUP_FILE")"
echo ""
echo "WARNING: This will replace the current database!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo "[$(date)] Stopping application..."
docker-compose stop rails-app

echo "[$(date)] Restoring database from backup..."
gunzip -c "$BACKUP_FILE" | docker-compose exec -T db pg_restore \
  -U postgres \
  -d androidspyware_production \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  --verbose

echo "[$(date)] Restarting application..."
docker-compose start rails-app

echo "[$(date)] Waiting for application to be ready..."
sleep 5

echo "================================================================"
echo "Restore completed successfully!"
echo "================================================================"
echo ""
echo "Verification steps:"
echo "1. Check application: http://localhost:3000"
echo "2. Review logs: docker-compose logs -f rails-app"
echo "3. Verify data: Check recent records in admin panel"
