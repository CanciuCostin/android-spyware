#!/bin/bash
# Verify backup integrity

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup_file>"
  exit 1
fi

echo "Verifying backup: $BACKUP_FILE"

# Check file integrity
if pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1; then
  echo "✓ Backup file is valid"
else
  echo "✗ Backup file is corrupted"
  exit 1
fi

# Check backup size
SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE")
if [ "$SIZE" -lt 1000 ]; then
  echo "✗ Backup file is too small ($SIZE bytes)"
  exit 1
fi

echo "✓ Backup verification passed"
