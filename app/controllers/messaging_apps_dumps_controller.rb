require "sqlite3"
require "minitar"

class MessagingAppsDumpsController < InheritedResources::Base
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
      puts "Error exporting database"
      puts e
    rescue
      puts "Error exporting database"
    ensure
      stm.close if stm
      db.close if db
    end
  end

  def uninstall_whatsapp_for_downgrade
    begin
      commandOutput = [run_adb_command("shell pm uninstall -k com.whatsapp")]
    rescue
      commandOutput = "Operation Failed"
      puts "Error uninstalling whatsapp."
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
      commandOutput = run_adb_command("install payloads/WhatsApp-v2.11.431-AndroidBucket.com.apk")
    rescue
      commandOutput = "Operation Failed"
      puts "Error installing old whatsapp version."
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
      commandOutput = run_adb_command("backup -apk com.whatsapp -f files/whatsapp/whatsapp_backup.ab")
    rescue
      commandOutput = "Operation Failed"
      puts "Error performing ADB backup."
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
      system("java -jar tools/android-backup-extractor/android-backup-extractor-20180521-bin/abe.jar unpack files/whatsapp/whatsapp_backup.ab files/whatsapp/whatsapp_backup.ab.tar")
    rescue
      puts "Error converting .ab file to .ab.tar"
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
      Minitar.unpack("files/whatsapp/whatsapp_backup.ab.tar", 'files\whatsapp\whatsapp_backup')
    rescue
      puts "Error extracting .tar backup file."
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
      commandOutput = run_adb_command("pull /sdcard/WhatsApp/Databases/msgstore.db.crypt12 files/whatsapp/msgstore.db.crypt12")
    rescue
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
      system("java -jar tools/crypt12-decrypt/master/decrypt12.jar files/whatsapp/whatsapp_backup/apps/com.whatsapp/f/key files/whatsapp/msgstore.db.crypt12 files/whatsapp/msgstore.db")
    rescue
      puts "Error decrypting db file"
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
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "whatsapp_dump_" + currentTimeFormat + ".txt" :
        fileName + ".txt"
      fullPath = "files/whatsapp/" + @fileName
      export_database(fullPath)
      commandOutput = ["Done"]
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newDump = MessagingAppsDump.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                          :app_name => "WhatsApp",
                                          :filename => @fileName,
                                          :smartphone_id => @smartphone.id)
          newDump.save!
          isOperationSuccessful = true
          break
        end
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue
      commandOutput = "Operation Failed"
    end
    respond_to do |format|
      format.js {
        render "export_whatsapp_database",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
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
