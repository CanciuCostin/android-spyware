# frozen_string_literal: true

require 'shellwords'

# Secure ADB command execution with command injection prevention
# SonarQube Rule: S2076 - Command injection prevention
class AdbCommandService
  class CommandError < StandardError; end

  # Allowed ADB shell commands (whitelist approach for security)
  ALLOWED_COMMANDS = %w[
    cat grep dumpsys ip date df getprop
    screencap screenrecord am pm settings input
  ].freeze

  def initialize(target)
    @target = sanitize_target(target)
    @adb_host = CredentialsService.adb_host
  end

  # Execute ADB shell command safely
  # SonarQube: Command injection prevented via sanitization
  def shell(command)
    validate_command!(command)
    execute("shell #{Shellwords.escape(command)}")
  end

  # Execute raw ADB command (internal use only)
  def execute(adb_command)
    full_command = build_adb_command(adb_command)
    Rails.logger.debug("Executing ADB: #{full_command}")
    
    result = `#{full_command}`
    raise CommandError, "ADB command failed" unless $?.success?
    
    result
  rescue StandardError => e
    Rails.logger.error("ADB command failed: #{e.message}")
    raise CommandError, e.message
  end

  # Safe file pull
  def pull(remote_path, local_path)
    sanitized_remote = Shellwords.escape(remote_path)
    sanitized_local = Shellwords.escape(local_path)
    execute("pull #{sanitized_remote} #{sanitized_local}")
  end

  # Safe file push
  def push(local_path, remote_path)
    sanitized_local = Shellwords.escape(local_path)
    sanitized_remote = Shellwords.escape(remote_path)
    execute("push #{sanitized_local} #{sanitized_remote}")
  end

  # Get device property safely
  def getprop(property)
    sanitized_prop = property.gsub(/[^a-zA-Z0-9._]/, '')
    shell("getprop #{sanitized_prop}")
  end

  # CPU usage calculation
  def cpu_usage
    stat1 = parse_cpu_stat
    sleep(0.5)
    stat2 = parse_cpu_stat

    work_delta = stat2[:work] - stat1[:work]
    total_delta = stat2[:total] - stat1[:total]
    
    return 0 if total_delta.zero?
    (work_delta * 100 / total_delta).to_i
  rescue StandardError => e
    Rails.logger.error("CPU usage calculation failed: #{e.message}")
    0
  end

  # Memory usage percentage
  def memory_usage
    meminfo = shell('cat /proc/meminfo')
    total = extract_meminfo(meminfo, 'MemTotal')
    available = extract_meminfo(meminfo, 'MemAvailable')
    
    return 0 if total.zero?
    ((total - available) / total * 100).to_i
  rescue StandardError => e
    Rails.logger.error("Memory usage calculation failed: #{e.message}")
    0
  end

  # Storage usage percentage
  def storage_usage
    df_output = shell('df /storage/emulated').split("\n").last
    parts = df_output.split
    total = parts[1].to_f
    used = parts[2].to_f
    
    return 0 if total.zero?
    (used / total * 100).to_i
  rescue StandardError => e
    Rails.logger.error("Storage usage calculation failed: #{e.message}")
    0
  end

  private

  def sanitize_target(target)
    # Only allow IP:port format or 'usb' keyword
    return 'usb' if target.to_s.downcase == 'usb'
    
    unless target.to_s.match?(/\A[\d.:]+\z/)
      raise CommandError, "Invalid ADB target format"
    end
    target
  end

  def validate_command!(command)
    base_command = command.to_s.split.first.to_s.downcase
    
    unless ALLOWED_COMMANDS.include?(base_command) || safe_compound_command?(command)
      raise CommandError, "Command not in whitelist: #{base_command}"
    end
  end

  def safe_compound_command?(command)
    # Allow piped commands if all parts are safe
    command.to_s.split(/[|;]/).all? do |part|
      base = part.strip.split.first.to_s.downcase
      ALLOWED_COMMANDS.include?(base)
    end
  end

  def build_adb_command(adb_command)
    base = "adb -H #{Shellwords.escape(@adb_host)}"
    base += " -s #{Shellwords.escape(@target)}" unless @target == 'usb'
    "#{base} #{adb_command}"
  end

  def parse_cpu_stat
    stat_line = shell('cat /proc/stat').split("\n").first
    values = stat_line.split.drop(1).map(&:to_f)
    {
      work: values.take(3).sum,
      total: values.sum
    }
  end

  def extract_meminfo(meminfo, key)
    line = meminfo.lines.find { |l| l.include?(key) }
    line&.gsub(/\D/, '').to_f
  end
end
