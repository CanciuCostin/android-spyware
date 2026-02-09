class StorageCleanupService < ApplicationService
  def call
    results = {
      expired: cleanup_expired_files,
      orphaned: cleanup_orphaned_files,
      stale_uploads: cleanup_stale_uploads,
      disk_usage: check_disk_usage
    }

    Result.success(results)
  rescue => e
    Rails.logger.error("StorageCleanupService failed: #{e.message}")
    Result.failure(e.message)
  end

  private

  def cleanup_expired_files
    retention_days = Rails.application.config.x.storage.retention_days
    cutoff = retention_days.days.ago
    expired = StoredFile.older_than(cutoff)
    count = 0

    expired.find_each do |stored_file|
      begin
        service = StorageService.new(backend: stored_file.storage_backend)
        service.delete(stored_file.storage_key)
        count += 1
      rescue => e
        Rails.logger.warn("Failed to delete expired file #{stored_file.storage_key}: #{e.message}")
      end
    end

    Rails.logger.info("Cleanup: removed #{count} expired files (older than #{retention_days} days)")
    { removed: count, cutoff: cutoff }
  end

  def cleanup_orphaned_files
    storage = StorageService.new
    all_keys = storage.list.value[:files] rescue []
    db_keys = StoredFile.pluck(:storage_key)
    orphaned_keys = all_keys - db_keys
    count = 0

    orphaned_keys.each do |key|
      begin
        storage.delete(key) unless StoredFile.exists?(storage_key: key)
        count += 1
      rescue => e
        Rails.logger.warn("Failed to delete orphaned file #{key}: #{e.message}")
      end
    end

    Rails.logger.info("Cleanup: removed #{count} orphaned files")
    { removed: count }
  end

  def cleanup_stale_uploads
    count = ResumableUploadService.cleanup_stale

    # Also clean tmp/chunks and tmp/assembled
    clean_stale_temp_dir(File.join(Rails.root, 'tmp', 'chunks'))
    clean_stale_temp_dir(File.join(Rails.root, 'tmp', 'assembled'))

    Rails.logger.info("Cleanup: removed #{count} stale uploads")
    { removed: count }
  end

  def check_disk_usage
    backend = Rails.application.config.x.storage.backend
    storage = StorageService.new(backend: backend)
    usage = storage.disk_usage
    alert_threshold = Rails.application.config.x.storage.disk_usage_alert_percent

    disk_info = if backend == 'local'
                  get_local_disk_info
                else
                  { total: nil, used_percent: nil }
                end

    if disk_info[:used_percent] && disk_info[:used_percent] >= alert_threshold
      Rails.logger.warn(
        "STORAGE ALERT: Disk usage at #{disk_info[:used_percent]}% " \
        "(threshold: #{alert_threshold}%)"
      )
    end

    {
      storage_bytes: usage,
      storage_human: human_size(usage),
      disk_total: disk_info[:total],
      disk_used_percent: disk_info[:used_percent],
      alert: disk_info[:used_percent] && disk_info[:used_percent] >= alert_threshold
    }
  end

  def get_local_disk_info
    root = Rails.application.config.x.storage.local_root.to_s
    if Gem.win_platform?
      drive = root[0..2]
      output = IO.popen(['wmic', 'logicaldisk', 'where', "DeviceID='#{drive[0..1]}'", 'get', 'FreeSpace,Size', '/format:csv'], &:read).to_s.strip
      lines = output.split("\n").reject(&:blank?)
      if lines.size >= 2
        parts = lines.last.split(',')
        free = parts[-2].to_i
        total = parts[-1].to_i
        used_percent = total > 0 ? (((total - free).to_f / total) * 100).round(1) : nil
        { total: total, used_percent: used_percent }
      else
        { total: nil, used_percent: nil }
      end
    else
      output = IO.popen(['df', '-B1', root], &:read).to_s.strip
      lines = output.split("\n")
      if lines.size >= 2
        parts = lines.last.split
        total = parts[1].to_i
        used_percent = parts[4].to_s.gsub('%', '').to_f
        { total: total, used_percent: used_percent }
      else
        { total: nil, used_percent: nil }
      end
    end
  rescue => e
    Rails.logger.warn("Could not determine disk usage: #{e.message}")
    { total: nil, used_percent: nil }
  end

  def clean_stale_temp_dir(dir)
    return unless Dir.exist?(dir)

    stale_hours = Rails.application.config.x.storage.stale_upload_hours
    cutoff = Time.current - stale_hours.hours

    Dir.entries(dir).each do |entry|
      next if entry.start_with?('.')
      path = File.join(dir, entry)
      if File.mtime(path) < cutoff
        FileUtils.rm_rf(path)
        Rails.logger.debug("Cleaned stale temp: #{path}")
      end
    end
  rescue => e
    Rails.logger.warn("Failed to clean #{dir}: #{e.message}")
  end

  def human_size(bytes)
    return '0 B' if bytes == 0
    units = %w[B KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.size - 1 if exp >= units.size
    "%.1f %s" % [bytes.to_f / (1024**exp), units[exp]]
  end
end
