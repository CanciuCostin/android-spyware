class BackupVerificationJob < ApplicationJob
  queue_as :maintenance
  
  def perform
    backup_dir = ENV['BACKUP_DIR'] || '/backups'
    latest_backup = Dir.glob("#{backup_dir}/eaglespy_db_*.sql.gz").max
    
    unless latest_backup
      alert_no_backup
      return
    end
    
    # Check backup age
    backup_age = Time.current - File.mtime(latest_backup)
    if backup_age > 25.hours
      alert_stale_backup(latest_backup, backup_age)
      return
    end
    
    # Verify backup integrity
    unless verify_backup(latest_backup)
      alert_corrupted_backup(latest_backup)
      return
    end
    
    Rails.logger.info "Backup verification passed: #{latest_backup}"
  end
  
  private
  
  def verify_backup(file)
    # Quick check: file size
    return false if File.size(file) < 1000
    
    # Full check: pg_restore --list
    system("pg_restore", "--list", file.to_s, out: File::NULL, err: File::NULL)
  end
  
  def alert_no_backup
    AlertService.trigger('backup_missing', nil, {
      severity: 'critical',
      message: 'No database backups found!'
    })
  end
  
  def alert_stale_backup(file, age)
    AlertService.trigger('backup_stale', nil, {
      severity: 'high',
      message: "Latest backup is #{(age / 3600).round} hours old",
      file: file
    })
  end
  
  def alert_corrupted_backup(file)
    AlertService.trigger('backup_corrupted', nil, {
      severity: 'critical',
      message: "Backup file is corrupted: #{file}"
    })
  end
end
