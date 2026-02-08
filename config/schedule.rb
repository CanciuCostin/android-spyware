# Daily backup at 2 AM
every 1.day, at: '2:00 am' do
  command "/app/scripts/backup_database.sh"
end

# Backup verification at 6 AM
every 1.day, at: '6:00 am' do
  runner "BackupVerificationJob.perform_later"
end

# Weekly backup test
every :sunday, at: '3:00 am' do
  command "/app/scripts/test_backup_restore.sh $(ls -t /backups/*.sql.gz | head -1)"
end
