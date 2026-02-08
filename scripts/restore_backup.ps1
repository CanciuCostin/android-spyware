# Quick Restore Script - Windows PowerShell

$ErrorActionPreference = "Stop"

param(
    [string]$BackupFile
)

# Find latest backup if not specified
if (-not $BackupFile) {
    $BACKUP_DIR = if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { "E:\EagleSpy Backups" }
    $BackupFile = Get-ChildItem $BACKUP_DIR -Filter "eaglespy_db_*.sql.gz" | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $BackupFile -or -not (Test-Path $BackupFile)) {
    Write-Host "Error: No backup file found"
    Write-Host "Usage: .\restore_backup.ps1 [backup_file]"
    Write-Host "Example: .\restore_backup.ps1 'E:\EagleSpy Backups\eaglespy_db_20260208.sql.gz'"
    exit 1
}

Write-Host "================================================================"
Write-Host "EagleSpy Database Restore"
Write-Host "================================================================"
Write-Host "Backup file: $BackupFile"
Write-Host "Backup size: $([math]::Round((Get-Item $BackupFile).Length / 1MB, 2)) MB"
Write-Host "Backup date: $((Get-Item $BackupFile).LastWriteTime)"
Write-Host ""
Write-Host "WARNING: This will replace the current database!"
Write-Host "Press Ctrl+C to cancel, or Enter to continue..."
Read-Host

Write-Host "[$((Get-Date))] Stopping application..."
docker-compose stop rails-app

Write-Host "[$((Get-Date))] Restoring database from backup..."
Get-Content $BackupFile | docker-compose exec -T db pg_restore `
    -U postgres `
    -d androidspyware_production `
    --clean `
    --if-exists `
    --no-owner `
    --no-acl `
    --verbose

Write-Host "[$((Get-Date))] Restarting application..."
docker-compose start rails-app

Write-Host "[$((Get-Date))] Waiting for application to be ready..."
Start-Sleep -Seconds 5

Write-Host "================================================================"
Write-Host "Restore completed successfully!"
Write-Host "================================================================"
Write-Host ""
Write-Host "Verification steps:"
Write-Host "1. Check application: http://localhost:3000"
Write-Host "2. Review logs: docker-compose logs -f rails-app"
Write-Host "3. Verify data: Check recent records in admin panel"
