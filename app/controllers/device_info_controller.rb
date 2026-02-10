class DeviceInfoController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender

  def dump_sysinfo
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      # Use get_device_info as it provides the same info and uses new protocol
      pending_command = send_command_and_wait(@smartphone, 'get_device_info', {}, timeout: 15.seconds)
      
      if pending_command.completed?
        raw = pending_command.response_data
        info = raw['payload'] || raw
        commandOutput = [
          "Brand: #{info['brand']}",
          "Model: #{info['model']}",
          "OS: #{info['os_version']}",
          "SDK: #{info['sdk_version']}",
          "Battery: #{info['battery_level']}%"
        ]
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error on dump sysinfo: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "dump_sysinfo",
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
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "dump_device_info", locals: { commandOutput: commandOutput }
      }
    end
  end

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

    if want_json?
      render json: { output: commandOutput }
      return
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

    if want_json?
      render json: { output: commandOutput }
      return
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
    
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "check_root", locals: { commandOutput: commandOutput }
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
      Rails.logger.error("[DeviceInfoController] toggle_wifi failed: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "toggle_wifi",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end
end
