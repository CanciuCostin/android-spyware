class CallLogsController < InheritedResources::Base
  def dump_calllogs
    begin
      commandTimeout = params[:exec_timeout].to_i
      downloadTimeout = params[:copy_timeout].to_i
      fileName = params[:filename].to_s
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      @fileName = fileName.empty? ?
        "calllogs_dump_" + currentTimeFormat + ".txt" :
        fileName + ".txt"
      processCommand = "dump_calllog -f text -o #{@fileName}"
      commandOutput = start_msf_process(processCommand)
      1.upto(commandTimeout) do |n|
        if system("docker exec kali_container sh -c \"ls | grep #{@fileName}\"")
          break
        else
          puts "Waiting ..."
        end
        sleep 1
      end
      copyCalllogsCommand = "docker cp kali_container:/#{@fileName} files/dumps/calllogs_dumps/#{@fileName}"
      system(copyCalllogsCommand)
      fullPath = "files/dumps/calllogs_dumps/" + @fileName
      isOperationSuccessful = false
      1.upto(downloadTimeout) do |n|
        if File.file?(fullPath)
          newCalllogsDump = CallLog.new(:date => currentTimeFormat.gsub("_", " ").gsub("--", ":"), :filename => @fileName, :smartphone_id => @smartphone.id)
          newCalllogsDump.save!
          isOperationSuccessful = true
          break
        end
      end
      commandOutput = ["Operation Failed"] if not isOperationSuccessful
    rescue
      puts "Error on dump call logs."
      commandOutput = ["Operation Failed"]
    end
    respond_to do |format|
      format.js {
        render "dump_calllogs",
               :locals => { :commandOutput => commandOutput,
                            :fileName => @fileName }
      }
    end
  end

  private

  def call_log_params
    params.require(:call_log).permit(:date,
                                     :filename,
                                     :smartphone_id)
  end
end
