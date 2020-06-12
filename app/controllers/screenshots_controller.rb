class ScreenshotsController < InheritedResources::Base

  private

    def screenshot_params
      params.require(:screenshot).permit(:date, :duration, :filename, :smartphone_id)
    end

    def dump_screenshot
      downloadTimeout=20
      @smartphone = Smartphone.find(params[:smartphone_id])

      currentTime = DateTime.now
      currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName= "screen_snap_" + currentTimeFormat + '.png'

      fullPath="app\\assets\\images\\files\\screen_snaps\\" + @fileName
      commandOutput=`tools\\platform-tools\\adb.exe shell screencap -p /sdcard/#{@fileName}`
      system("tools\\platform-tools\\adb.exe pull /sdcard/#{@fileName} #{@fullPath}")
      isOperationSuccessful=false
      1.upto(downloadTimeout) do |n|
          if File.file?(fullPath)
              newScreenshot=Screenshot.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
              newScreenshot.save!
              isOperationSuccessful = true
              break
          end 
      end
      commandOutput=["Operation Failed"] if not isOperationSuccessful

        respond_to do |format|
          format.js { render "dump_screen_snap", :locals => {:commandOutput => commandOutput.split('\n')}  }
        end
    end

    def dump_screenrecord
      downloadTimeout=20
      @smartphone = Smartphone.find(params[:smartphone_id])

      currentTime = DateTime.now
      currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName= "screen_record_" + currentTimeFormat + '.mp4'

      fullPath="app\\assets\\images\\files\\screen_snaps\\" + @fileName
      commandOutput=`tools\\platform-tools\\adb.exe shell screenrecord --time-limit 3 /sdcard/#{@fileName}`
      system("tools\\platform-tools\\adb.exe pull /sdcard/#{@fileName} #{@fullPath}")
      isOperationSuccessful=false
      1.upto(downloadTimeout) do |n|
          if File.file?(fullPath)
              newScreenshot=Screenshot.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
              newScreenshot.save!
              isOperationSuccessful = true
              break
          end 
      end
      commandOutput=["Operation Failed"] if not isOperationSuccessful

        respond_to do |format|
          format.js { render "dump_screen_record", :locals => {:commandOutput => commandOutput.split('\n')}  }
        end
    end


end
