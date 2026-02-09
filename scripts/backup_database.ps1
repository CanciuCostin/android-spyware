# EagleSpy Database Backup Script (Windows)

$ErrorActionPreference = "Stop"

# Configuration
$BACKUP_DIR = if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { "E:\EagleSpy Backups" }
$RETENTION_DAYS = if ($env:RETENTION_DAYS) { $env:RETENTION_DAYS } else { 30 }
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$BACKUP_FILE = "$BACKUP_DIR\eaglespy_db_$TIMESTAMP.sql.gz"

# Create backup directory
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

Write-Host "[$((Get-Date))] Starting database backup..."

# Docker exec pg_dump
docker-compose exec -T db pg_dump -U postgres -F c -Z 9 androidspyware_production > $BACKUP_FILE

Write-Host "[$((Get-Date))] Backup completed: $BACKUP_FILE"

# Calculate size
$BACKUP_SIZE = (Get-Item $BACKUP_FILE).Length / 1MB
Write-Host "[$((Get-Date))] Backup size: $([math]::Round($BACKUP_SIZE, 2)) MB"

# Cleanup old backups
Write-Host "[$((Get-Date))] Cleaning up old backups..."
Get-ChildItem $BACKUP_DIR -Filter "eaglespy_db_*.sql.gz" | 
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RETENTION_DAYS) } | 
  Remove-Item

Write-Host "[$((Get-Date))] Backup process finished"
