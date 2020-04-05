class ApkPayloadsController < InheritedResources::Base

  private

    def apk_payload_params
      params.require(:apk_payload).permit(:destination_ip, :destination_port, :forwarding_ip, :forwarding_port, :name)
    end

end
