#!/bin/bash
# Point-in-Time Recovery Script

set -e

BACKUP_FILE="$1"
TARGET_TIME="$2"  # Format: "2026-02-08 12:00:00"

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_TIME" ]; then
  echo "Usage: $0 <backup_file> <target_time>"
  echo "Example: $0 /backups/eaglespy_db_20260208.sql.gz '2026-02-08 12:00:00'"
  exit 1
fi

echo "Restoring database to point-in-time: $TARGET_TIME"

# Stop application
docker-compose stop rails-app

# Restore base backup
echo "Restoring base backup..."
gunzip -c "$BACKUP_FILE" | docker-compose exec -T db pg_restore \
  -U postgres -d androidspyware_production --clean --if-exists

# Create recovery.conf for PITR
cat > recovery.conf <<EOF
restore_command = 'cp /backups/wal/%f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = promote
EOF

# Copy recovery.conf to container
docker cp recovery.conf $(docker-compose ps -q db):/var/lib/postgresql/data/

# Restart database for recovery
docker-compose restart db

echo "PITR restore initiated. Database will recover to $TARGET_TIME"
echo "Monitor logs: docker-compose logs -f db"
