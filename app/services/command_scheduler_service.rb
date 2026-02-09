# frozen_string_literal: true

class CommandSchedulerService < ApplicationService
  include CommandSender

  def initialize(scheduled_command = nil)
    @scheduled_command = scheduled_command
  end

  # Execute a single scheduled command
  def call
    return Result.failure('No scheduled command provided') unless @scheduled_command
    return Result.failure('Command is not active') unless @scheduled_command.active?
    return Result.failure('Command is not due') unless @scheduled_command.due?
    return Result.failure('Max runs reached') if @scheduled_command.max_runs_reached?

    execute_command
  end

  # Class method: find and execute all due commands
  def self.execute_due_commands
    due_commands = ScheduledCommand.due.includes(:smartphone).to_a
    results = []

    due_commands.each do |scheduled_command|
      result = new(scheduled_command).call
      results << { id: scheduled_command.id, result: result }
      Rails.logger.info "[CommandScheduler] Command ##{scheduled_command.id} (#{scheduled_command.command}): #{result.success? ? 'success' : result.error}"
    rescue StandardError => e
      Rails.logger.error "[CommandScheduler] Failed to execute command ##{scheduled_command.id}: #{e.message}"
      results << { id: scheduled_command.id, result: Result.failure(e.message) }
    end

    results
  end

  # Parse a cron expression and calculate next run time
  def self.next_run_time(cron_expression, from: Time.current)
    return nil if cron_expression.blank?

    parts = cron_expression.strip.split(/\s+/)
    unless parts.length == 5
      raise ArgumentError, "Invalid cron expression: expected 5 fields (minute hour day month weekday)"
    end

    minute_spec, hour_spec, day_spec, month_spec, weekday_spec = parts

    # Search up to 366 days ahead
    candidate = from.beginning_of_minute + 1.minute
    (0..525_600).each do |_|
      if matches_cron?(candidate, minute_spec, hour_spec, day_spec, month_spec, weekday_spec)
        return candidate
      end
      candidate += 1.minute
    end

    nil
  end

  # Validate a cron expression
  def self.valid_cron?(expression)
    return false if expression.blank?

    parts = expression.strip.split(/\s+/)
    return false unless parts.length == 5

    ranges = [0..59, 0..23, 1..31, 1..12, 0..6]
    parts.each_with_index.all? do |part, i|
      valid_cron_field?(part, ranges[i])
    end
  end

  private

  def execute_command
    smartphone = @scheduled_command.smartphone
    return Result.failure('Device not found') unless smartphone

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    pending_command = send_command_async(
      smartphone,
      @scheduled_command.command,
      @scheduled_command.params || {}
    )

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    @scheduled_command.record_execution!(
      status: 'success',
      result: { request_id: pending_command.request_id, command: pending_command.command },
      duration_ms: duration_ms,
      pending_command: pending_command
    )

    Result.success(pending_command)
  rescue StandardError => e
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - (start_time || Process.clock_gettime(Process::CLOCK_MONOTONIC))) * 1000).round

    @scheduled_command.record_execution!(
      status: 'failed',
      result: { error: e.message },
      duration_ms: duration_ms
    )

    Result.failure(e.message)
  end

  # Cron matching helpers
  def self.matches_cron?(time, minute_spec, hour_spec, day_spec, month_spec, weekday_spec)
    matches_field?(time.min, minute_spec, 0..59) &&
      matches_field?(time.hour, hour_spec, 0..23) &&
      matches_field?(time.day, day_spec, 1..31) &&
      matches_field?(time.month, month_spec, 1..12) &&
      matches_field?(time.wday, weekday_spec, 0..6)
  end

  def self.matches_field?(value, spec, range)
    return true if spec == '*'

    spec.split(',').any? do |part|
      if part.include?('/')
        base, step = part.split('/')
        step = step.to_i
        return false if step <= 0

        start_val = base == '*' ? range.first : base.to_i
        (start_val..range.last).step(step).include?(value)
      elsif part.include?('-')
        low, high = part.split('-').map(&:to_i)
        (low..high).include?(value)
      else
        value == part.to_i
      end
    end
  end

  def self.valid_cron_field?(field, range)
    return true if field == '*'

    field.split(',').all? do |part|
      if part.include?('/')
        base, step = part.split('/')
        return false unless step.to_s =~ /\A\d+\z/ && step.to_i > 0
        base == '*' || (base.to_s =~ /\A\d+\z/ && range.include?(base.to_i))
      elsif part.include?('-')
        low, high = part.split('-')
        low.to_s =~ /\A\d+\z/ && high.to_s =~ /\A\d+\z/ &&
          range.include?(low.to_i) && range.include?(high.to_i)
      else
        part =~ /\A\d+\z/ && range.include?(part.to_i)
      end
    end
  rescue StandardError
    false
  end
end
