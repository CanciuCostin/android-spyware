class ContactsController < InheritedResources::Base
  def dump_contacts
    begin
      commandTimeout = params[:exec_timeout].to_i
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "contacts_dump_" + currentTimeFormat + ".txt" :
        fileName + ".txt"
      processCommand = "dump_contacts -f text -o #{@fileName}"
      commandOutput = start_msf_process(processCommand)
      1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      copyContactsCommand = "docker cp kali_container:/#{@fileName} files/dumps/contacts_dumps/#{@fileName}"
      system(copyContactsCommand)
      fullPath = "files/dumps/contacts_dumps/" + @fileName
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newContactsDump = Contact.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                        :filename => @fileName,
                                        :smartphone_id => @smartphone.id)
          newContactsDump.save!
          isOperationSuccessful = true
          break
        end
        sleep 1
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue
      puts "Error on dump contacts."
      commandOutput = ["Operation Failed"]
    end
    respond_to do |format|
      format.js {
        render "dump_contacts", :locals => { :commandOutput => commandOutput,
                                             :fileName => @fileName }
      }
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:date, :filename, :smartphone_id)
  end
end
