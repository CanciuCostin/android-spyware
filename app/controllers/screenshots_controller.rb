class ScreenshotsController < InheritedResources::Base


  def dump_screen_snap
    downloadTimeout=params[:copy_timeout].to_i
    @smartphone = Smartphone.find(params[:smartphone_id])

    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    @fileName= "screen_snap_" + currentTimeFormat + '.png'

    fullPath="app\\assets\\images\\files\\screen_snaps\\" + @fileName
    commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell screencap -p /sdcard/#{@fileName}`.split("\n")
    system("tools\\platform-tools\\adb.exe -s 192.168.100.33 pull /sdcard/#{@fileName} app\\assets\\images\\files\\screen_snaps")
    isOperationSuccessful=false
    puts downloadTimeout
    1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
            newScreenshot=Screenshot.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
            newScreenshot.save!
            isOperationSuccessful = true
            break
        end 
       sleep 1
    end

    commandOutput=["Operation Failed"] if not isOperationSuccessful
    puts commandOutput
      respond_to do |format|
        format.js { render "dump_screen_snap", :locals => { :commandOutput => commandOutput, :fileName => @fileName }  }
      end
  end

  def screen_record
    downloadTimeout=params[:copy_timeout].to_i
    @smartphone = Smartphone.find(params[:smartphone_id])

    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    @fileName= "screen_record_" + currentTimeFormat + '.mp4'

    fullPath="app\\assets\\images\\files\\screen_snaps\\" + @fileName
    commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell screenrecord --time-limit 5 /sdcard/#{@fileName}`
    system("tools\\platform-tools\\adb.exe -s 192.168.100.33 pull /sdcard/#{@fileName} app\\assets\\images\\files\\screen_snaps")
    isOperationSuccessful=false
    1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
            newScreenshot=Screenshot.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
            newScreenshot.save!
            isOperationSuccessful = true
            break
        end
       sleep 1
    end
    commandOutput=["Operation Failed"] if not isOperationSuccessful

      respond_to do |format|
        format.js { render "screen_record", :locals => {:commandOutput => commandOutput.split('\n'), :fileName => @fileName}  }
      end
  end

  private

    def screenshot_params
      params.require(:screenshot).permit(:date, :duration, :filename, :smartphone_id)
    end




end
