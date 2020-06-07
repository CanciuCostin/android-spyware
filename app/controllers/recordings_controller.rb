class RecordingsController < InheritedResources::Base

  def microphone_rec
    commandTimeout=20
    downloadTimeout=20
    @smartphone = Smartphone.find(params[:smartphone_id])

    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    @fileName= "microphone_rec_" + currentTimeFormat + '.wav'
    processCommand="record_mic -d 10 -f #{@fileName}"
    sleep(5)
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
    copyRecCommand="docker cp kali_container:/#{@fileName} app\\assets\\images\\files\\microphone_recs\\#{@fileName}"
    system(copyRecCommand)

    fullPath="app\\assets\\images\\files\\microphone_recs\\" + @fileName
    isOperationSuccessful=false
    1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
            newRec=Recording.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'), :duration => 5, :filename => @fileName, :smartphone_id => @smartphone.id)
            newRec.save!
            isOperationSuccessful = true
            break
        end 
    end
    commandOutput=["Operation Failed"] if not isOperationSuccessful

    respond_to do |format|
        format.js { render "microphone_rec", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
      end
end

  private

    def recording_params
      params.require(:recording).permit(:date, :duration, :filename, :smartphone_id)
    end

end
