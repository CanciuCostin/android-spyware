namespace :storage do
  desc 'Run storage cleanup (expired files, orphans, stale uploads)'
  task cleanup: :environment do
    puts "[Storage] Running cleanup..."
    result = StorageCleanupService.call

    if result.success?
      data = result.value
      puts "  Expired files removed: #{data[:expired][:removed]}"
      puts "  Orphaned files removed: #{data[:orphaned][:removed]}"
      puts "  Stale uploads removed: #{data[:stale_uploads][:removed]}"
      disk = data[:disk_usage]
      puts "  Storage usage: #{disk[:storage_human]}"
      if disk[:alert]
        puts "  ⚠ ALERT: Disk usage at #{disk[:disk_used_percent]}%!"
      end
    else
      puts "  ERROR: #{result.error}"
    end
    puts "[Storage] Cleanup complete."
  end

  desc 'Deduplicate stored files'
  task deduplicate: :environment do
    puts "[Storage] Running deduplication..."
    result = DeduplicationService.new.deduplicate_files

    if result.success?
      puts "  Files deduplicated: #{result.value[:deduplicated]}"
      puts "  Space saved: #{result.value[:saved_human]}"
    else
      puts "  ERROR: #{result.error}"
    end
    puts "[Storage] Deduplication complete."
  end

  desc 'Show storage statistics'
  task stats: :environment do
    puts "[Storage] Statistics"
    puts "  Backend: #{Rails.application.config.x.storage.backend}"

    total_files = StoredFile.count
    total_size = StoredFile.sum(:size)
    puts "  Total files: #{total_files}"
    puts "  Total size: #{human_size(total_size)}"

    puts "\n  By backend:"
    StoredFile.group(:storage_backend).count.each do |backend, count|
      size = StoredFile.by_backend(backend).sum(:size)
      puts "    #{backend}: #{count} files (#{human_size(size)})"
    end

    dedup_report = DeduplicationService.report
    puts "\n  Deduplication potential:"
    puts "    Duplicate groups: #{dedup_report[:duplicate_groups]}"
    puts "    Duplicate files: #{dedup_report[:total_duplicate_files]}"
    puts "    Wasted space: #{dedup_report[:wasted_human]}"

    orphaned = StoredFile.orphaned.count
    puts "\n  Orphaned records: #{orphaned}"

    stale = UploadChunk.stale.distinct.count(:upload_id)
    puts "  Stale uploads: #{stale}"

    storage = StorageService.new
    usage = storage.disk_usage
    puts "\n  Current disk usage: #{human_size(usage)}"
  end

  desc 'Migrate files from local storage to S3'
  task migrate_to_s3: :environment do
    unless ENV['S3_BUCKET'].present?
      puts "ERROR: S3_BUCKET environment variable is required"
      exit 1
    end

    local_files = StoredFile.by_backend('local')
    total = local_files.count
    puts "[Storage] Migrating #{total} files from local to S3..."

    local = StorageService.new(backend: 'local')
    s3 = StorageService.new(backend: 's3')
    migrated = 0
    errors = 0

    local_files.find_each.with_index do |stored_file, index|
      begin
        # Download from local
        download_result = local.download(stored_file.storage_key)
        unless download_result.success?
          puts "  SKIP #{stored_file.storage_key}: #{download_result.error}"
          errors += 1
          next
        end

        local_path = download_result.value[:path]

        # Upload to S3 with same key
        s3_result = s3.upload(
          local_path,
          original_filename: stored_file.original_filename,
          content_type: stored_file.content_type,
          metadata: stored_file.metadata || {}
        )

        if s3_result.success?
          # Update database record
          stored_file.update!(
            storage_backend: 's3',
            storage_key: s3_result.value[:key]
          )
          # Remove local copy
          File.delete(local_path) if File.exist?(local_path)
          migrated += 1
        else
          puts "  FAIL #{stored_file.storage_key}: #{s3_result.error}"
          errors += 1
        end

        print "\r  Progress: #{index + 1}/#{total} (#{migrated} migrated, #{errors} errors)"
      rescue => e
        puts "\n  ERROR #{stored_file.storage_key}: #{e.message}"
        errors += 1
      end
    end

    puts "\n[Storage] Migration complete: #{migrated} migrated, #{errors} errors"
  end
end

def human_size(bytes)
  return '0 B' if bytes.nil? || bytes == 0
  units = %w[B KB MB GB TB]
  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = units.size - 1 if exp >= units.size
  "%.1f %s" % [bytes.to_f / (1024**exp), units[exp]]
end
