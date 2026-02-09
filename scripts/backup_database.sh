#!/bin/bash
# EagleSpy Database Backup Script

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DB_NAME="${POSTGRES_DB:-androidspyware_production}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/eaglespy_db_$TIMESTAMP.sql.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting database backup..."

# Perform backup with compression
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$DB_HOST" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --verbose \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_FILE"

echo "[$(date)] Backup completed: $BACKUP_FILE"

# Calculate backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup size: $BACKUP_SIZE"

# Cleanup old backups
echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "eaglespy_db_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Upload to S3 (if configured)
if [ -n "$AWS_S3_BUCKET" ]; then
  echo "[$(date)] Uploading to S3..."
  aws s3 cp "$BACKUP_FILE" "s3://$AWS_S3_BUCKET/backups/" --storage-class STANDARD_IA
  echo "[$(date)] S3 upload complete"
fi

echo "[$(date)] Backup process finished"
