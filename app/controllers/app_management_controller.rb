class AppManagementController < ApplicationController
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender

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

    if want_json?
      render json: { output: commandOutput }
      return
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
        if apk_file_param.is_a?(ActionDispatch::Http::UploadedFile)
          upload_dir = Rails.root.join('public', 'uploads', 'apk')
          FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)

          filename = SecureRandom.uuid + File.extname(apk_file_param.original_filename)
          filepath = upload_dir.join(filename)

          File.write(filepath, apk_file_param.read)
          apk_path = "/uploads/apk/#{filename}"
        else
          apk_path = apk_file_param
        end

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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "install_apk", locals: { commandOutput: commandOutput }
      }
    end
  end

  def install_app
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      app_path = params[:app]

      # SECURITY: Validate path to prevent directory traversal attacks
      if app_path.present?
        resolved_path = File.realpath(File.expand_path(app_path)) rescue nil
        allowed_dirs = [
          Rails.root.join('files', 'payloads').to_s,
          Rails.root.join('tools').to_s
        ]

        unless resolved_path && allowed_dirs.any? { |dir| resolved_path.start_with?(dir) }
          commandOutput = ["Error: Invalid file path - access denied"]
          if want_json?
            render json: { output: commandOutput }
            return
          end
          respond_to do |format|
            format.js { render "install_app", locals: { commandOutput: commandOutput } }
          end
          return
        end

        if File.file?(resolved_path)
          apk_data = File.read(resolved_path)
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "install_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def run_app
    begin
      app_name = params[:app] || params[:package_name]
      @smartphone = Smartphone.find(params[:smartphone_id])

      if app_name.present?
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "run_app", locals: { commandOutput: commandOutput }
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "open_app", locals: { commandOutput: commandOutput }
      }
    end
  end

  def uninstall_app
    begin
      app_name = params[:app] || params[:package_name]
      @smartphone = Smartphone.find(params[:smartphone_id])

      if app_name.present?
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

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "uninstall_app",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end
end
