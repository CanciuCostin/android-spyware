ActiveAdmin.register ApkInstallation do
  menu priority: 2, label: "📲 Install APK", parent: "📦 APK"

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
      require 'open3'
      require 'shellwords'
      
      @apk_payload = ApkPayload.find(apk_installation.apk_payload_id)
      adb_host = ENV["ADB_HOST"] || 'localhost'
      
      # Validate ADB_HOST to prevent command injection
      unless adb_host =~ /\A[a-zA-Z0-9.\-]+\z/
        Rails.logger.error("[ApkInstallation] Invalid ADB_HOST: #{adb_host}")
        raise StandardError, "Invalid ADB host"
      end
      
      # Get ADB devices using safe command execution
      stdout, stderr, status = Open3.capture3('adb', '-H', adb_host, 'devices')
      unless status.success?
        Rails.logger.error("[ApkInstallation] ADB devices command failed: #{stderr}")
        raise StandardError, "ADB command failed"
      end
      
      adbDevices = stdout.split("\n")
      adbTarget = apk_installation.target_ip
      
      # Validate target_ip format
      unless adbTarget == "usb" || adbTarget =~ /\A[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\z/
        Rails.logger.error("[ApkInstallation] Invalid target IP: #{adbTarget}")
        raise StandardError, "Invalid target IP"
      end
      
      if (adbTarget == "usb" and adbDevices.size > 1 and adbDevices.any? { |line| line.strip.end_with? "device" }) or adbDevices.any? { |line| line =~ /#{Regexp.escape(adbTarget)}:5555\s+device/ }
        adbTarget = adbDevices.find { |line| line.strip.end_with? "device" }.split[0] if adbTarget == "usb"
      end
      if adbTarget.upcase == "USB"
        adbTarget = adbDevices.find { |line| line.strip.end_with? "device" }.split[0]
      end
      
      # Safe APK installation with validated parameters
      apk_path = Rails.root.join('files/payloads', "#{@apk_payload.name}.apk")
      unless File.exist?(apk_path)
        Rails.logger.error("[ApkInstallation] APK file not found: #{apk_path}")
        raise StandardError, "APK file not found"
      end
      
      stdout, stderr, status = Open3.capture3('adb', '-H', adb_host, '-s', adbTarget, 'install', apk_path.to_s)
      
      unless status.success?
        Rails.logger.error("[ApkInstallation] APK install failed: #{stderr}")
        raise StandardError, "APK installation failed"
      end
      
      Rails.logger.info("[ApkInstallation] Successfully installed #{@apk_payload.name}.apk on #{adbTarget}")
    rescue StandardError => e
      Rails.logger.error("[ApkInstallation] Error installing APK: #{e.message}")
      raise
    end
  end

  permit_params :target_ip, :status, :apk_payload_id
end
