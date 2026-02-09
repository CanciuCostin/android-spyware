class ScreenshotResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    image_base64 = @response['image']
    if image_base64
      image_data = Base64.decode64(image_base64)

      unless valid_image?(image_data)
        Rails.logger.warn("Invalid screenshot data from smartphone #{@smartphone.id}: failed image validation")
        @pending_command.mark_failed('Invalid image data')
        return
      end

      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filepath = "files/dumps/screenshots/screenshot_#{@smartphone.id}_#{timestamp}.png"
      FileUtils.mkdir_p(File.dirname(filepath))
      
      File.binwrite(filepath, image_data)
      
      # Create Screenshot model record
      Screenshot.create(
        smartphone_id: @smartphone.id,
        filename: filepath
      )
      
      # Mark pending_command as completed
      @pending_command.mark_completed(@response.merge('file' => filepath))
    else
      @pending_command.mark_failed('No image data')
    end
  end

  private

  def valid_image?(data)
    return false if data.blank? || data.bytesize < 100
    return false if data.bytesize > 10.megabytes

    # Check magic bytes for PNG/JPEG
    magic = data[0..7].bytes
    png_magic = [137, 80, 78, 71, 13, 10, 26, 10]
    jpeg_magic = [255, 216, 255]

    magic[0..7] == png_magic || magic[0..2] == jpeg_magic
  end
end
