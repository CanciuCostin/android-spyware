class AdbService
  def initialize(target = nil)
    @host = ENV['ADB_HOST'] || 'host.docker.internal'
    @port = ENV['ADB_PORT'] || 5037
    @target = target
  end

  def execute(command)
    SpywareTracing.trace_adb_operation(command) do |span|
      full_cmd = "adb -H #{@host} -P #{@port}"
      full_cmd += " -s #{@target}" if @target
      full_cmd += " #{command}"
      
      span.set_attribute('adb.command_raw', command)
      span.set_attribute('adb.full_command', full_cmd)

      Rails.logger.debug("ADB Exec: #{full_cmd}")
      output = `#{full_cmd}`
      status = $?
      
      span.set_attribute('adb.exit_code', status.exitstatus)
      
      if status.success?
        span.set_attribute('adb.status', 'success')
        return output.strip
      else
        span.set_attribute('adb.status', 'failure')
        span.set_attribute('adb.error', output)
        Rails.logger.error("ADB Error: #{output}")
        return nil
      end
    end
  end
  
  # Wrapper for shell commands
  def shell(cmd)
    execute("shell \"#{cmd}\"")
  end

  # Common operations
  def device_info
    {
      uptime: shell("uptime"),
      model: shell("getprop ro.product.model"),
      android_version: shell("getprop ro.build.version.release")
    }
  end
end
