ActiveAdmin.register_page "Remote" do
  menu priority: 6, label: "Remote"
  
    content title: proc { "Remote" } do
  
      
  
  
      #render partial: "switch"
      #render partial: "smartphones/dropdown_smartphones", smartphones: Smartphone.all, smartphone: Smartphone.first
  
      columns do
        column do
            columns do 
                if params[:selected_smartphone_id].present?
                    column  do
                        render template: "smartphones/smartphone2", locals: {smartphones: Smartphone.all, smartphone: Smartphone.find(params[:selected_smartphone_id])}
                    end
                else
                    column  do
                        render template: "smartphones/smartphone2", locals: {smartphones: Smartphone.all, smartphone: Smartphone.first}
                    end
                end
            end
            columns do
                column do
                    panel "Device Load "do
                        render partial: "gauges"
                    end
                end
            end
        end
    




        column do
            columns do
                column do
                    panel "Record Setings "do
                        render partial: "input_box", locals: {input_name: "File Name"}
                        render partial: "sliders"
                        #render partial: "sliders"
                        render partial: "switcher"
                    end
                end
            end
        columns  do
            column class: "a" do
                panel "SMS Setings "do
                render partial: "input_box", locals: {input_name: "Destination Number"}
                render partial: "input_box", locals: {input_name: "Content"}
                end
            end
        end
        columns  do
            column class: "a" do
                panel "System Setings "do
                render partial: "dropdown"
                end
            end
        end
        
    end


    column do
        columns do 
            column do
                render template: "smartphones/terminal"
            end
        end
        columns do
            column do
                panel "Platform Processes" do
                    render partial: "line_chart"
                end
            end
        end
    end

    end

   
   # render partial: "switcher"

    # columns do
    #     column do
    #         render partial: "sliders"
    #     end
    #     column do
    #          render partial: "dropdown"
    #     end
    #     column do
    #         render partial: "input_counter"
    #     end
    # end

    # columns do
    #     column do
    #         render partial: "input_box"
    #     end
    #     column do
    #         render partial: "counter"
    #     end
    #     column do
    #     end
    # end
      
  
    #    div class: "blank_slate_container", id: "dashboard_default_message" do
    #     span class: "blank_slate" do
    #       span I18n.t("active_admin.dashboard_welcome.welcome")
    #       small I18n.t("active_admin.dashboard_welcome.call_to_action")
    #     end
    #    end  
  
    end # content
  end
  