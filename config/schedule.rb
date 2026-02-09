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

# Partition management - create next 3 months of keylogs partitions
every '0 1 1 * *' do
  rake "db:partitions:create_future[3]"
end

# Materialized view refresh (device_summaries_cached)
every 15.minutes do
  rake "db:maintenance:refresh_views"
end

# Database vacuum/analyze
every 1.day, at: '3:00 am' do
  rake "db:maintenance:vacuum_analyze"
end

# Old partition cleanup - archive and drop partitions older than 6 months
every '0 4 1 * *' do
  rake "db:partitions:archive_old[6]"
  rake "db:partitions:cleanup_old[6]"
end

# Partition verification
every :monday, at: '5:00 am' do
  rake "db:partitions:verify"
end
