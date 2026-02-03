require "msfrpc-client"
require "date"
require_relative "../../lib/msf_instrumentation"

class ApplicationController < ActionController::Base
  include MsfInstrumentation::ApplicationControllerMixin
  
  # SonarQube Fix: Use instance variables with memoization instead of class variables
  # Rule S1121 - Class variables create thread-safety issues
  class << self
    attr_accessor :adb_target, :adb_connected, :msf_connected,
                  :cpu_usage, :memory_usage, :storage,
                  :nr_finished_processes, :nr_running_processes,
                  :sound_mode, :adb_started, :ip_address,
                  :operating_system, :is_rooted, :battery_level, :local_hour
  end

  # Initialize defaults
  self.adb_target = nil
  self.adb_connected = false
  self.msf_connected = false
  self.cpu_usage = 0
  self.memory_usage = 0
  self.storage = 0
  self.nr_finished_processes = 0
  self.nr_running_processes = 0
  self.sound_mode = 2
  self.adb_started = false
  self.ip_address = "Unknown"
  self.operating_system = "Unknown"
  self.is_rooted = "Unknown"
  self.battery_level = "Unknown"
  self.local_hour = "Unknown"

  # SonarQube Fix: Use centralized services instead of duplicated code
  def get_active_session_id(_smartphone = nil)
    msf_service.android_session_id
  rescue MsfRpcService::ConnectionError => e
    Rails.logger.error("MSF connection error: #{e.message}")
    nil
  end

  # Wrapping legacy helpers with traced implementations
  def start_msf_process(command)
    start_msf_process_traced(command)
  end

  # SonarQube Fix: Use secure AdbCommandService instead of raw shell
  def run_adb_command(command)
    adb_service.shell(command.to_s.gsub('shell ', ''))
  rescue AdbCommandService::CommandError => e
    Rails.logger.error("ADB command failed: #{e.message}")
    run_adb_command_traced(command)
  end

  # SonarQube Fix: Use MsfRpcService - no hardcoded credentials
  def detach_session
    msf_service.detach_session
  rescue MsfRpcService::SessionError => e
    Rails.logger.error("Detach session failed: #{e.message}")
    "Operation Failed: #{e.message}"
  end

  # SonarQube Fix: Use AdbCommandService for safe command execution
  def update_cpu_usage
    self.class.cpu_usage = adb_service.cpu_usage
  rescue AdbCommandService::CommandError => e
    Rails.logger.error("CPU update failed: #{e.message}")
    self.class.cpu_usage = 0
  end

  def update_memory_usage
    self.class.memory_usage = adb_service.memory_usage
  rescue AdbCommandService::CommandError => e
    Rails.logger.error("Memory update failed: #{e.message}")
    self.class.memory_usage = 0
  end

  def update_storage_usage
    self.class.storage = adb_service.storage_usage
  rescue AdbCommandService::CommandError => e
    Rails.logger.error("Storage update failed: #{e.message}")
    self.class.storage = 0
  end

  def update_device_info
    self.class.ip_address = adb_service.shell("ip addr show wlan0 | grep inet | grep -v inet6").split[1].to_s.gsub(/\/\d*/, "")
    self.class.operating_system = "Android #{adb_service.getprop('ro.build.version.release').strip}"
    self.class.is_rooted = "Rooted: No"
    self.class.local_hour = adb_service.shell("date +%R").strip
    battery_output = adb_service.shell("dumpsys battery | grep level")
    self.class.battery_level = "#{battery_output.split(':').last&.strip}%"
  rescue AdbCommandService::CommandError => e
    Rails.logger.error("Device info update failed: #{e.message}")
  end

  # SonarQube Fix: Use MsfRpcService - eliminates hardcoded credentials & DRY
  def check_msf_connection
    self.class.msf_connected = msf_service.connected?
    msf_service.start_handler if self.class.msf_connected
  rescue MsfRpcService::ConnectionError => e
    Rails.logger.error("MSF Container is Down: #{e.message}")
    self.class.msf_connected = false
  rescue StandardError => e
    Rails.logger.error("Failed checking MSF Connection: #{e.message}")
    self.class.msf_connected = false
  end

  def check_adb_connection
    self.class.adb_target = Rails.configuration.spyware_config["target_ip"]
    
    adb_devices = `adb -H #{CredentialsService.adb_host} devices`.split("\n")
    target = self.class.adb_target
    
    connected = if target == "usb"
      adb_devices.size > 1 && adb_devices.any? { |line| line.strip.end_with?("device") }
    else
      adb_devices.any? { |line| line =~ /#{Regexp.escape(target)}:5555\s+device/ }
    end

    if connected
      # Update target to actual device ID for USB connections
      if target == "usb"
        device_line = adb_devices.find { |line| line.strip.end_with?("device") }
        self.class.adb_target = device_line.split[0] if device_line
      end
      
      self.class.adb_connected = true
      update_cpu_usage
      update_memory_usage
      update_storage_usage
      update_device_info
    else
      self.class.adb_connected = false
    end
  rescue StandardError => e
    Rails.logger.error("Error checking ADB connection: #{e.message}")
    self.class.adb_connected = false
  end

  def check_connection
    check_msf_connection
    check_adb_connection
    respond_to do |format|
      format.js {
        render "check_connection", locals: {
          adbConnected: self.class.adb_connected,
          msfConnected: self.class.msf_connected,
          cpuUsage: self.class.cpu_usage,
          memoryUsage: self.class.memory_usage,
          storage: self.class.storage,
          nrRunningProcesses: self.class.nr_running_processes,
          nrFinishedProcesses: self.class.nr_finished_processes,
          ipAddress: self.class.ip_address,
          operatingSystem: self.class.operating_system,
          isRooted: self.class.is_rooted,
          batteryLevel: self.class.battery_level,
          localHour: self.class.local_hour
        }
      }
    end
  end

  private

  # Memoized service instances
  def msf_service
    @msf_service ||= MsfRpcService.new
  end

  def adb_service
    @adb_service ||= AdbCommandService.new(self.class.adb_target)
  end
end
