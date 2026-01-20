
puts "========================================"
puts "       DASHBOARD DIAGNOSTICS            "
puts "========================================"

# 1. Check ADB
puts "\n[1] Checking ADB Connection..."
adb_host = ENV['ADB_HOST']
puts "ADB_HOST: #{adb_host}"
devices_output = `adb -H #{adb_host} devices`
puts "Output:\n#{devices_output}"

if devices_output.include?("device") && !devices_output.strip.end_with?("attached")
  puts "✅ ADB Connection OK"
else
  puts "❌ ADB Connection FAILED"
end

# 2. Check Database
puts "\n[2] Checking Database..."
count = Smartphone.count
puts "Smartphones in DB: #{count}"
Smartphone.all.each do |s|
  puts " - Device ##{s.id}: #{s.name} (OS: #{s.operating_system})"
end

# 3. Check Metasploit
puts "\n[3] Checking Metasploit Connection..."
begin
  require 'msfrpc-client'
  
  host = ENV['RAILS_HOST'] || 'metasploit'
  puts "Connecting to MSF at #{host}:3333..."
  
  rpc = Msf::RPC::Client.new(
    host: host,
    port: 3333,
    uri: '/api/',
    ssl: true # Code uses ssl: true
  )
  
  # Try found credentials
  user = 'cool'
  password = 'looc'
  puts "Logging in as '#{user}'..."
  res = rpc.login(user, password)
  puts "Login Result: #{res}"
  
  sessions = rpc.call('session.list')
  puts "Sessions Count: #{sessions.count}"
  puts "Sessions: #{sessions.inspect}"
  
  if sessions.any?
    sid = sessions.keys.first
    puts "Testing Command on Session #{sid}..."
    res = rpc.call('session.meterpreter_command', sid, 'sysinfo')
    puts "Command Result: #{res}"
  else
    puts "⚠️ No active sessions. Please launch the payload on the device."
  end

rescue => e
  puts "❌ Metasploit Error: #{e.message}"
  puts e.backtrace.join("\n")
end
