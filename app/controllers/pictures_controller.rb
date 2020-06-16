class PicturesController < InheritedResources::Base

    #handle no session issue!
    def take_picture
        puts params[:open]
        puts params[:download]
        puts params[:exec_timeout]
        puts params[:copy_timeout]

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
