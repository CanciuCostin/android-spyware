class ApkInstallationsController < InheritedResources::Base

  private

    def apk_installation_params
      params.require(:apk_installation).permit(:taget_ip, :status, :apk_payload_id)
    end

end
