class WhatsAppResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end

  def process
    whatsapp_messages = @response['whatsapp_messages'] || []
    timestamp = Time.current.strftime("%Y-%m-%d_%H--%M--%S")
    filename = "whatsapp_dump_#{timestamp}.txt"
    
    file_path = Rails.root.join('files', 'dumps', 'whatsapp', filename)
    FileUtils.mkdir_p(File.dirname(file_path))
    
    content = whatsapp_messages.map do |message|
      sender = message['sender'] || 'Unknown'
      body = message['body'] || ''
      date = format_date(message['timestamp'] || message['date'])
      message_type = message['type'] == 'received' ? 'Received' : 'Sent'
      is_group = message['is_group_message'] ? '[GROUP]' : ''
      "#{message_type} from: #{sender} #{is_group}\nTime: #{date}\nMessage: #{body}\n\n"
    end.join
    
    File.write(file_path, content)
    
    MessagingAppsDump.create!(
      date: timestamp.gsub("_", " ").gsub("--", ":"),
      app_name: "WhatsApp",
      filename: filename,
      smartphone_id: @smartphone.id
    )
    
    @pending_command.mark_completed(@response)
  end
  
  private
  
  def format_date(timestamp)
    return 'Unknown' if timestamp.blank?
    
    begin
      # Handle millisecond timestamps
      time = Time.at(timestamp.to_i / 1000.0)
      time.strftime('%Y-%m-%d %H:%M:%S')
    rescue
      'Unknown'
    end
  end
end
