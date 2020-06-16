class SmsMessagesController < InheritedResources::Base
  def dump_messages

    commandTimeout=params[:exec_timeout].to_i
    downloadTimeout=params[:copy_timeout].to_i
    @smartphone = Smartphone.find(params[:smartphone_id])

    currentTime = DateTime.now
    currentTimeFormat=currentTime.strftime("%Y-%m-%d_%H--%M--%S")
    @fileName= "sms_messages_dump_" + currentTimeFormat + '.txt'
    processCommand="dump_sms -o #{@fileName}"
    commandOutput=start_msf_process(processCommand)

    1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
            break
        else
            puts "Waiting ..."
        end
        sleep 1
      end
    copyMessagesCommand="docker cp kali_container:/#{@fileName} app\\assets\\images\\files\\sms_messages_dumps\\#{@fileName}"
    system(copyMessagesCommand)

    fullPath="app\\assets\\images\\files\\sms_messages_dumps\\" + @fileName
    isOperationSuccessful=false
    1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
            newMessageDump=SmsMessage.new(:date => currentTimeFormat.gsub('_',' ').gsub('--',':'),:filename => @fileName, :smartphone_id => @smartphone.id)
            newMessageDump.save!
            isOperationSuccessful = true
            break
        end 
    end
    commandOutput=["Operation Failed"] if not isOperationSuccessful

    respond_to do |format|
        format.js { render "dump_messages", :locals => {:commandOutput => commandOutput, :fileName => @fileName}  }
      end
end

  private

    def sms_message_params
      params.require(:sms_message).permit(:date, :filename, :smartphone_id)
    end

end
