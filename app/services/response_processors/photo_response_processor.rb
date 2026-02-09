class PhotoResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    image_base64 = @response['image']
    if image_base64
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "photo_#{@smartphone.id}_#{timestamp}.jpg"
      filepath = "files/dumps/pictures/#{filename}"
      
      # Create directory
      FileUtils.mkdir_p(File.dirname(filepath))
      
      # Decode and save image
      File.binwrite(filepath, Base64.decode64(image_base64))
      
      # Create Picture model record
      Picture.create!(
        smartphone_id: @smartphone.id,
        filename: filename
      )
      
      # Mark command as completed
      @pending_command.mark_completed(@response.merge('file' => filepath))
    else
      @pending_command.mark_failed('No image data')
    end
  end
end
