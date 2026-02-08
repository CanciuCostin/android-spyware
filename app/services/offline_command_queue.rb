# frozen_string_literal: true

# Queues commands for offline devices and auto-sends when they reconnect.
# Commands are persisted to the queued_commands table with priority ordering and TTL.
class OfflineCommandQueue < ApplicationService
  MAX_QUEUE_SIZE = 100
  DEFAULT_TTL = 24.hours
  DEFAULT_PRIORITY = 5 # 1 = highest, 10 = lowest

  def initialize(device_id, command = nil, params: {}, priority: DEFAULT_PRIORITY, ttl: DEFAULT_TTL)
    @device_id = device_id
    @command = command
    @params = params
    @priority = priority.clamp(1, 10)
    @ttl = ttl
  end

  # Enqueue a command for a device
  def call
    return Result.failure("device_id is required") if @device_id.blank?
    return Result.failure("command is required") if @command.blank?

    smartphone = Smartphone.find_by(device_id: @device_id)
    return Result.failure("Unknown device: #{@device_id}") unless smartphone

    # If device is online, send directly
    if HeartbeatMonitor.is_online?(@device_id)
      return send_directly(smartphone)
    end

    enqueue(smartphone)
  end

  # Process all queued commands for a device that just came online
  def self.flush_for_device(device_id)
    smartphone = Smartphone.find_by(device_id: device_id)
    return 0 unless smartphone

    # Expire stale commands first
    expire_stale_commands(device_id)

    commands = QueuedCommand.where(smartphone: smartphone, status: 'pending')
                            .order(priority: :asc, created_at: :asc)

    sent_count = 0
    commands.find_each do |queued|
      begin
        queued.update!(status: 'sending')

        ActionCable.server.broadcast(
          "commands_#{device_id}",
          { type: 'command', action: queued.command, params: queued.params || {} }
        )

        queued.update!(status: 'sent', sent_at: Time.current)
        sent_count += 1
      rescue StandardError => e
        Rails.logger.error "[OfflineCommandQueue] Failed to send queued command #{queued.id}: #{e.message}"
        queued.update!(status: 'failed', error_message: e.message)
      end
    end

    Rails.logger.info "[OfflineCommandQueue] Flushed #{sent_count} commands for device #{device_id}"
    sent_count
  end

  # Remove expired commands
  def self.expire_stale_commands(device_id = nil)
    scope = QueuedCommand.where(status: 'pending').where('expires_at < ?', Time.current)
    scope = scope.joins(:smartphone).where(smartphones: { device_id: device_id }) if device_id
    expired_count = scope.update_all(status: 'expired')

    Rails.logger.info "[OfflineCommandQueue] Expired #{expired_count} stale commands" if expired_count > 0
    expired_count
  end

  # Queue stats for a device
  def self.queue_stats(device_id)
    smartphone = Smartphone.find_by(device_id: device_id)
    return {} unless smartphone

    {
      pending: QueuedCommand.where(smartphone: smartphone, status: 'pending').count,
      sent: QueuedCommand.where(smartphone: smartphone, status: 'sent').count,
      failed: QueuedCommand.where(smartphone: smartphone, status: 'failed').count,
      expired: QueuedCommand.where(smartphone: smartphone, status: 'expired').count
    }
  end

  private

  def enqueue(smartphone)
    # Enforce max queue size per device
    pending_count = QueuedCommand.where(smartphone: smartphone, status: 'pending').count
    if pending_count >= MAX_QUEUE_SIZE
      return Result.failure("Queue full for device #{@device_id} (#{MAX_QUEUE_SIZE} max)")
    end

    queued = QueuedCommand.create!(
      smartphone: smartphone,
      command: @command,
      params: @params,
      priority: @priority,
      status: 'pending',
      expires_at: Time.current + @ttl
    )

    Rails.logger.info "[OfflineCommandQueue] Queued command '#{@command}' for offline device #{@device_id}"
    Result.success(queued)
  rescue StandardError => e
    Rails.logger.error "[OfflineCommandQueue] Failed to enqueue: #{e.message}"
    Result.failure(e.message)
  end

  def send_directly(smartphone)
    ActionCable.server.broadcast(
      "commands_#{@device_id}",
      { type: 'command', action: @command, params: @params }
    )

    Result.success({ sent_directly: true, command: @command })
  rescue StandardError => e
    Rails.logger.error "[OfflineCommandQueue] Direct send failed, queueing: #{e.message}"
    enqueue(smartphone)
  end
end
