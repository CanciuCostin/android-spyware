class ScreenshotsController < InheritedResources::Base
  def dump_screen_snap
    begin
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "screen_snap_" + currentTimeFormat + ".png" :
        fileName + ".png"
      fullPath = "files/dumps/screen_snaps/" + @fileName
      run_adb_command("shell screencap -p /sdcard/#{@fileName}").split("\n")
      run_adb_command("pull /sdcard/#{@fileName} files/dumps/screen_snaps")
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newScreenshot = Screenshot.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                         :filename => @fileName,
                                         :smartphone_id => @smartphone.id)
          newScreenshot.save!
          isOperationSuccessful = true
          break
        end
        sleep 1
      end
      commandOutput = isOperationSuccessful ? ["Screen snap saved."] : ["Operation Failed"]
    rescue
      commandOutput = ["Operation Failed"]
      puts "Error on dump screen snap."
    end
    respond_to do |format|
      format.js {
        render "dump_screen_snap",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  def screen_record
    begin
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      time = params[:time].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "screen_record_" + currentTimeFormat + ".mp4" :
        fileName + ".mp4"
      fullPath = "files/dumps/screen_snaps/" + @fileName
      run_adb_command("shell screenrecord --time-limit #{time} /sdcard/#{@fileName}").split("\n")
      run_adb_command("pull /sdcard/#{@fileName} files/dumps/screen_snaps")
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newScreenshot = Screenshot.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                         :filename => @fileName,
                                         :smartphone_id => @smartphone.id)
          newScreenshot.save!
          isOperationSuccessful = true
          break
        end
        sleep 1
      end
      commandOutput = isOperationSuccessful ? ["Screen record saved."] : ["Operation Failed"]
    rescue
      commandOutput = ["Operation Failed"]
      puts "Error on dump screen record."
    end
    respond_to do |format|
      format.js {
        render "screen_record",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  private

  def screenshot_params
    params.require(:screenshot).permit(:date,
                                       :duration,
                                       :filename,
                                       :smartphone_id)
  end
end
