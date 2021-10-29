class RecordingsController < InheritedResources::Base
  def microphone_rec
    begin
      time = params[:time].to_s
      commandTimeout = params[:exec_timeout].to_i
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ? "microphone_rec_" + currentTimeFormat + ".wav" : fileName + ".wav"
      processCommand = "record_mic -d #{time} -f #{@fileName}"
      commandOutput = start_msf_process(processCommand)
      1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      copyRecCommand = "docker cp kali_container:/#{@fileName} files/dumps/microphone_recs/#{@fileName}"
      system(copyRecCommand)
      fullPath = "files/dumps/microphone_recs/" + @fileName
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newRec = Recording.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                 :duration => 5,
                                 :filename => @fileName,
                                 :smartphone_id => @smartphone.id)
          newRec.save!
          isOperationSuccessful = true
          break
        end
        sleep 1
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue
      puts "Error on microphone rec."
      commandOutput = ["Operation Failed"]
    end
    respond_to do |format|
      format.js {
        render "microphone_rec",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  private

  def recording_params
    params.require(:recording).permit(:date,
                                      :duration,
                                      :filename,
                                      :smartphone_id)
  end
end
