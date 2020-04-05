class SmsMessagesController < InheritedResources::Base

  private

    def sms_message_params
      params.require(:sms_message).permit(:date, :source, :destination, :content, :smartphone_id)
    end

end
