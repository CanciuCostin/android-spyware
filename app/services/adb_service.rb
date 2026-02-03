# frozen_string_literal: true

require 'shellwords'
require 'open3'

# SonarQube Rules Applied:
# - S2076: Command injection prevention via Shellwords
# - S108: Proper error handling (no empty catch blocks)
# - S1192: DRY - centralized command execution
class AdbService
  class CommandError < StandardError; end

  def initialize(target = nil)
    @host = CredentialsService.adb_host
    @port = ENV.fetch('ADB_PORT', '5037')
    @target = sanitize_target(target)
  end

  # SonarQube S2076: Safe command execution using Open3
  def execute(command)
    SpywareTracing.trace_adb_operation(command) do |span|
      args = build_adb_args(command)
      
      span.set_attribute('adb.command_raw', command)
      span.set_attribute('adb.args', args.join(' '))

      Rails.logger.debug("ADB Exec: adb #{args.join(' ')}")
      
      # Use Open3 instead of backticks for security
      output, status = Open3.capture2e('adb', *args)
      
      span.set_attribute('adb.exit_code', status.exitstatus)
      
      if status.success?
        span.set_attribute('adb.status', 'success')
        output.strip
      else
        span.set_attribute('adb.status', 'failure')
        span.set_attribute('adb.error', output)
        Rails.logger.error("ADB Error: #{output}")
        raise CommandError, "ADB command failed: #{output}"
      end
    end
  end
  
  # SonarQube S2076: Shell commands properly escaped
  def shell(cmd)
    # Sanitize shell command to prevent injection
    sanitized = Shellwords.escape(cmd)
    execute("shell #{sanitized}")
  end

  # Common operations with proper error handling (SonarQube S108)
  def device_info
    {
      uptime: safe_shell("uptime"),
      model: safe_shell("getprop ro.product.model"),
      android_version: safe_shell("getprop ro.build.version.release")
    }
  rescue CommandError => e
    Rails.logger.error("Failed to get device info: #{e.message}")
    { uptime: 'N/A', model: 'Unknown', android_version: 'Unknown' }
  end

  private

  # SonarQube S2076: Sanitize target to prevent injection
  def sanitize_target(target)
    return nil if target.nil?
    
    # Only allow valid target formats: IP:port or device serial
    if target =~ /\A[\w\-.:]+\z/
      target
    else
      Rails.logger.warn("Invalid ADB target format: #{target}")
      nil
    end
  end

  # Build ADB arguments array (safe from injection)
  def build_adb_args(command)
    args = ['-H', @host, '-P', @port.to_s]
    args += ['-s', @target] if @target
    args + command.split(' ', 2) # Split command and arguments
  end

  # Safe shell wrapper with error handling
  def safe_shell(cmd)
    shell(cmd)
  rescue CommandError
    'N/A'
  end
end
