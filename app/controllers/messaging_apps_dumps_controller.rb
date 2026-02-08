require "sqlite3"
require "minitar"
require "open3"
require "shellwords"

class MessagingAppsDumpsController < InheritedResources::Base
  include CommandSender

  def export_database(filePath)
    begin
      db = SQLite3::Database.open "files/dumps/whatsapp/msgstore.db"
      stm = db.prepare "SELECT _id,key_remote_jid,data,timestamp FROM messages;"
      rs = stm.execute
      File.open(filePath, "w") do |file|
        rs.each do |row|
          file.write(row.join("---") + "\n")
        end
      end
    rescue SQLite3::Exception => e
      Rails.logger.error("Error exporting database: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Error exporting database: #{e.message}")
    ensure
      stm.close if stm
      db.close if db
    end
  end

  def uninstall_whatsapp_for_downgrade
    begin
      commandOutput = [run_adb_command("shell pm uninstall -k com.whatsapp")]
    rescue StandardError => e
      commandOutput = "Operation Failed"
      Rails.logger.error("[MessagingAppsDumps] Error uninstalling whatsapp: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "uninstall_whatsapp_for_downgrade",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def install_old_apk
    begin
      commandOutput = run_adb_command("install tools/WhatsApp-v2.11.431-AndroidBucket.com.apk")
    rescue StandardError => e
      commandOutput = "Operation Failed"
      Rails.logger.error("[MessagingAppsDumps] Error installing old whatsapp version: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "install_old_apk",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def adb_backup
    begin
      Thread.new {
        sleep(5)
        run_adb_command("shell input keyevent 82")
        run_adb_command("shell input tap 521 1130")
      }
      commandOutput = run_adb_command("backup -apk com.whatsapp -f files/dumps/whatsapp/whatsapp_backup.ab")
    rescue StandardError => e
      commandOutput = "Operation Failed"
      Rails.logger.error("[MessagingAppsDumps] Error performing ADB backup: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "adb_backup",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def extract_backup
    begin
      # Safe command execution with Open3
      jar_path = Rails.root.join('tools/android-backup-extractor/android-backup-extractor-20180521-bin/abe.jar')
      input_file = Rails.root.join('files/dumps/whatsapp/whatsapp_backup.ab')
      output_file = Rails.root.join('files/dumps/whatsapp/whatsapp_backup.ab.tar')
      
      unless File.exist?(jar_path) && File.exist?(input_file)
        Rails.logger.error("[MessagingAppsDumps] Required files not found for backup extraction")
        raise StandardError, "Required files missing"
      end
      
      stdout, stderr, status = Open3.capture3(
        'java', '-jar', jar_path.to_s, 'unpack', input_file.to_s, output_file.to_s
      )
      
      unless status.success?
        Rails.logger.error("[MessagingAppsDumps] Extract failed: #{stderr}")
        raise StandardError, "Extraction failed"
      end
    rescue StandardError => e
      Rails.logger.error("[MessagingAppsDumps] Error converting .ab file: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "extract_backup",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def untar_backup
    begin
      Minitar.unpack("files/dumps/whatsapp/whatsapp_backup.ab.tar", 'files\whatsapp\whatsapp_backup')
    rescue StandardError => e
      Rails.logger.error("[MessagingAppsDumps] Error extracting .tar backup file: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "untar_backup",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def pull_whatsapp_db
    begin
      commandOutput = run_adb_command("pull /sdcard/WhatsApp/Databases/msgstore.db.crypt12 files/dumps/whatsapp/msgstore.db.crypt12")
    rescue StandardError => e
      Rails.logger.error("[MessagingAppsDumps] Error pulling WhatsApp DB: #{e.message}")
      commandOutput = "Operation Failed"
    end
    respond_to do |format|
      format.js {
        render "pull_whatsapp_db",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def decrypt_whatsapp_database
    begin
      # Safe command execution with Open3
      jar_path = Rails.root.join('tools/crypt12-decrypt/master/decrypt12.jar')
      key_file = Rails.root.join('files/dumps/whatsapp/whatsapp_backup/apps/com.whatsapp/f/key')
      encrypted_db = Rails.root.join('files/dumps/whatsapp/msgstore.db.crypt12')
      output_db = Rails.root.join('files/dumps/whatsapp/msgstore.db')
      
      unless File.exist?(jar_path) && File.exist?(key_file) && File.exist?(encrypted_db)
        Rails.logger.error("[MessagingAppsDumps] Required files not found for database decryption")
        raise StandardError, "Required files missing"
      end
      
      stdout, stderr, status = Open3.capture3(
        'java', '-jar', jar_path.to_s, key_file.to_s, encrypted_db.to_s, output_db.to_s
      )
      
      unless status.success?
        Rails.logger.error("[MessagingAppsDumps] Decrypt failed: #{stderr}")
        raise StandardError, "Decryption failed"
      end
    rescue StandardError => e
      Rails.logger.error("[MessagingAppsDumps] Error decrypting db file: #{e.message}")
    end
    respond_to do |format|
      format.js {
        render "decrypt_whatsapp_database",
               :locals => { :copy_timeout => params[:copy_timeout].to_i,
                            :smartphone_id => params[:smartphone_id] }
      }
    end
  end

  def export_whatsapp_database
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      # Send command asynchronously via ActionCable
      # WhatsAppResponseProcessor will handle saving the messages
      pending_command = send_command_async(@smartphone, 'dump_whatsapp_messages', {})
      
      commandOutput = ["WhatsApp message extraction initiated..."]
    rescue => e
      Rails.logger.error("Error dumping WhatsApp messages: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "export_whatsapp_database",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  private

  def messaging_apps_dump_params
    params.require(:messaging_apps_dump).permit(:date,
                                                :app_name,
                                                :filename,
                                                :smartphone_id)
  end
end
