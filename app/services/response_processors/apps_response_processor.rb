class AppsResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    apps = @response['apps'] || []
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filepath = "files/dumps/apps/apps_#{@smartphone.id}_#{timestamp}.txt"
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, apps.to_json)
    @pending_command.mark_completed(@response.merge('file' => filepath))
  end
end
