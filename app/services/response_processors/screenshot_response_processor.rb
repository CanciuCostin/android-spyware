class ScreenshotResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    image_base64 = @response['image']
    if image_base64
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filepath = "files/dumps/screenshots/screenshot_#{@smartphone.id}_#{timestamp}.png"
      FileUtils.mkdir_p(File.dirname(filepath))
      File.binwrite(filepath, Base64.decode64(image_base64))
      @pending_command.mark_completed(@response.merge('file' => filepath))
    else
      @pending_command.mark_failed('No image data')
    end
  end
end
