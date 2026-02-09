class ContactsResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @smartphone = pending_command.smartphone
  end
  
  def process
    contacts_data = @response['contacts'] || []
    timestamp = Time.current.strftime("%Y-%m-%d_%H--%M--%S")
    filename = "contacts_dump_#{timestamp}.txt"
    
    file_path = Rails.root.join('files', 'dumps', 'contacts_dumps', filename)
    FileUtils.mkdir_p(File.dirname(file_path))
    
    content = contacts_data.map do |contact|
      "Name: #{contact['name']}\nPhone: #{contact['phone_number']}\nEmail: #{contact['email']}\n\n"
    end.join
    
    File.write(file_path, content)
    
    Contact.create!(
      date: timestamp.gsub("_", " ").gsub("--", ":"),
      filename: filename,
      smartphone_id: @smartphone.id
    )
    
    @pending_command.mark_completed(@response)
  end
end
