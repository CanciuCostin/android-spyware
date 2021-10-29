class PicturesController < InheritedResources::Base
  def take_picture
    begin
      fileName = params[:filename].to_s
      commandTimeout = params[:exec_timeout].to_i
      downloadTimeout = params[:copy_timeout].to_i
      camera = params[:back_camera] == "true" ? "1" : "2"
      quality = params[:quality].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "webcam_snap_" + currentTimeFormat + ".jpeg" :
        fileName + ".jpeg"
      processCommand = "webcam_snap -q #{quality} -i #{camera} -p #{@fileName}"
      commandOutput = start_msf_process(processCommand)
      1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      copyPictureCommand = "docker cp kali_container:/#{@fileName} files/dumps/pictures/#{@fileName}"
      system(copyPictureCommand)
      fullPath = "files/dumps/pictures/" + @fileName
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newPicture = Picture.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                   :filename => @fileName,
                                   :smartphone_id => @smartphone.id)
          newPicture.save!
          isOperationSuccessful = true
          break
        end
        sleep 1
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue => e
      puts "Error on webcam snap."
      puts e
      commandOutput = ["Operation Failed"]
    end
    respond_to do |format|
      format.js {
        render "take_picture",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  private

  def picture_params
    params.require(:picture).permit(:date,
                                    :duration,
                                    :filename,
                                    :smartphone_id)
  end
end
