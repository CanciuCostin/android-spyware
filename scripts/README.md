# EagleSpy Backup & Recovery Scripts

This directory contains scripts for automated backup, verification, and disaster recovery.

## Scripts

### Backup Scripts

#### `backup_database.sh` (Linux/Unix)
Performs automated PostgreSQL backup with compression and optional S3 upload.

**Usage**:
```bash
./backup_database.sh
```

**Environment Variables**:
- `BACKUP_DIR`: Backup directory (default: `/backups`)
- `RETENTION_DAYS`: Days to keep backups (default: 30)
- `POSTGRES_PASSWORD`: Database password
- `AWS_S3_BUCKET`: Optional S3 bucket for offsite backup

#### `backup_database.ps1` (Windows)
Windows PowerShell version of the backup script.

**Usage**:
```powershell
.\backup_database.ps1
```

**Environment Variables**:
- `BACKUP_DIR`: Backup directory (default: `E:\EagleSpy Backups`)
- `RETENTION_DAYS`: Days to keep backups (default: 30)

### Recovery Scripts

#### `restore_pitr.sh`
Point-in-Time Recovery script for restoring database to specific timestamp.

**Usage**:
```bash
./restore_pitr.sh /backups/eaglespy_db_20260208.sql.gz '2026-02-08 12:00:00'
```

**Arguments**:
1. Path to base backup file
2. Target timestamp (format: `YYYY-MM-DD HH:MM:SS`)

### Verification Scripts

#### `verify_backup.sh`
Verifies backup file integrity without performing a full restore.

**Usage**:
```bash
./verify_backup.sh /backups/eaglespy_db_20260208.sql.gz
```

**Checks**:
- File exists and is readable
- File size is reasonable
- PostgreSQL can parse backup metadata

#### `test_backup_restore.sh`
Performs full restore test in isolated test database.

**Usage**:
```bash
./test_backup_restore.sh /backups/eaglespy_db_20260208.sql.gz
```

**Process**:
1. Creates temporary test database
2. Restores backup
3. Runs validation queries
4. Cleans up test database

### S3 Scripts

#### `backup_to_s3.sh`
Uploads local backups to AWS S3 with lifecycle management.

**Usage**:
```bash
export AWS_S3_BUCKET="your-bucket-name"
./backup_to_s3.sh
```

**Prerequisites**:
- AWS CLI installed and configured
- S3 bucket created
- IAM permissions for S3 write access

## Setup

### Linux/Unix

Make scripts executable:

```bash
chmod +x *.sh
```

### Windows

PowerShell scripts are ready to use. Ensure execution policy allows running scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Scheduling

### Cron (Linux/Unix)

Edit crontab:

```bash
crontab -e
```

Add daily backup at 2 AM:

```cron
0 2 * * * /path/to/scripts/backup_database.sh >> /var/log/eaglespy-backup.log 2>&1
```

### Task Scheduler (Windows)

Create scheduled task:

```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
  -Argument '-File "E:\EagleSpy V5\scripts\backup_database.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 2AM
Register-ScheduledTask -TaskName "EagleSpy Backup" -Action $action -Trigger $trigger
```

### Using Whenever Gem

The project uses the `whenever` gem for scheduling. See `config/schedule.rb`:

```ruby
every 1.day, at: '2:00 am' do
  command "/app/scripts/backup_database.sh"
end
```

Update crontab:

```bash
whenever --update-crontab
```

## Troubleshooting

### Permission Denied

Linux/Unix:
```bash
chmod +x scripts/*.sh
```

Windows:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### pg_dump Not Found

Ensure PostgreSQL client tools are installed or run via Docker:

```bash
docker-compose exec db pg_dump ...
```

### S3 Upload Fails

Check AWS credentials:

```bash
aws sts get-caller-identity
```

Configure if needed:

```bash
aws configure
```

## Documentation

For complete documentation, see:
- [BACKUP_DISASTER_RECOVERY.md](../BACKUP_DISASTER_RECOVERY.md) - Comprehensive backup documentation
- [DR_RUNBOOK.md](../DR_RUNBOOK.md) - Disaster recovery procedures

## Support

For issues or questions:
1. Check script output for error messages
2. Verify environment variables are set correctly
3. Review logs: `docker-compose logs db`
4. Consult documentation files
