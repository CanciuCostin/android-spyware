namespace :spyware do
  desc "Remove data older than X days"
  task clean_old_data: :environment do
    raw_days = ENV['DATA_RETENTION_DAYS']

    days =
      if raw_days.nil? || raw_days.strip.empty?
        30
      else
        begin
          Integer(raw_days)
        rescue ArgumentError
          30
        end
      end
      file_deleted = true
      if File.exist?(path)
        begin
          File.delete(path)
          puts "  Deleted #{path}"
        rescue => e
          file_deleted = false
          puts "  Error deleting #{path}: #{e.class} - #{e.message}"
        end
      end
      if file_deleted
        rec.destroy
      else
        puts "  Skipped database delete for Picture##{rec.id} due to file deletion error"
      end
    end

    # 2. Screenshots
    puts "Processing Screenshots..."
    Screenshot.where('created_at < ?', limit).find_each do |rec|
      path = Rails.root.join('files', 'dumps', 'screen_snaps', rec.filename)
      file_deleted = true
      if File.exist?(path)
        begin
          File.delete(path)
          puts "  Deleted #{path}"
        rescue => e
          file_deleted = false
          puts "  Error deleting #{path}: #{e.class} - #{e.message}"
        end
      end
      if file_deleted
        rec.destroy
      else
        puts "  Skipped database delete for Screenshot##{rec.id} due to file deletion error"
      end
    end

    # 3. Recordings
    puts "Processing Recordings..."
    Recording.where('created_at < ?', limit).find_each do |rec|
      path = Rails.root.join('files', 'dumps', 'microphone_recs', rec.filename)
      file_deleted = true
      if File.exist?(path)
        begin
          File.delete(path)
          puts "  Deleted #{path}"
        rescue => e
          file_deleted = false
          puts "  Error deleting #{path}: #{e.class} - #{e.message}"
        end
      end
      if file_deleted
        rec.destroy
      else
        puts "  Skipped database delete for Recording##{rec.id} due to file deletion error"
      end
        File.delete(path)
        puts "  Deleted #{path}"
      end
      rec.destroy
    end

    # 3. Recordings
    puts "Processing Recordings..."
    Recording.where('created_at < ?', limit).find_each do |rec|
      path = Rails.root.join('files', 'dumps', 'microphone_recs', rec.filename)
      if File.exist?(path)
        File.delete(path)
        puts "  Deleted #{path}"
      end
      rec.destroy
    end

    puts "[Cleanup] Done."
  end
end
