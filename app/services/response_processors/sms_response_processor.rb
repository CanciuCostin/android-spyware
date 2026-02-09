class SmsResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    sms_messages = @response['sms_messages'] || []
    timestamp = Time.current.strftime("%Y-%m-%d_%H--%M--%S")
    filename = "sms_dump_#{timestamp}.txt"
    
    file_path = Rails.root.join('files', 'dumps', 'sms', filename)
    FileUtils.mkdir_p(File.dirname(file_path))
    
    content = sms_messages.map do |message|
      sender = message['sender'] || 'Unknown'
      body = message['body'] || ''
      date = format_date(message['date'])
      message_type = message['type'] == 1 ? 'Received' : 'Sent'
      "#{message_type} from: #{sender}\nTime: #{date}\nMessage: #{body}\n\n"
    end.join
    
    File.write(file_path, content)
    
    SmsMessage.find_or_create_by!(
      filename: filename,
      smartphone_id: @smartphone.id
    ) do |m|
      m.date = timestamp.gsub("_", " ").gsub("--", ":")
    end
    
    @pending_command.mark_completed(@response)
  end
  
  private
  
  def format_date(timestamp)
    return 'Unknown' if timestamp.blank?
    
    begin
      # Handle millisecond timestamps
      time = Time.at(timestamp / 1000.0)
      time.strftime('%Y-%m-%d %H:%M:%S')
    rescue
      'Unknown'
    end
  end
end
