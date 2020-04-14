
class SmartphonesController < InheritedResources::Base
    


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
